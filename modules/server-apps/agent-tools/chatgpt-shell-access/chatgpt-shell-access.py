"""Provide bounded shell execution on explicitly configured hosts."""

import asyncio
import base64
import json
import os
import shlex
import signal
import time
import uuid
from contextlib import suppress
from dataclasses import dataclass, field
from pathlib import PurePosixPath
from typing import Literal

import authorization
from mcp.server import MCPServer

MAX_OUTPUT_BYTES = 512 * 1024
OUTPUT_HEAD_BYTES = 64 * 1024
OUTPUT_TAIL_BYTES = MAX_OUTPUT_BYTES - OUTPUT_HEAD_BYTES
MAX_JOBS = 64
JOB_RETENTION_SECONDS = 30 * 60
WAIT_SECONDS = 10.0
MAX_WAIT_SECONDS = 30.0
CANCEL_GRACE_SECONDS = 2.0
HERDR_EXEC_TIMEOUT_SECONDS = 600


@dataclass(frozen=True)
class RemoteTarget:
    """SSH connection settings for a configured remote host."""

    ssh_target: str
    credential: str
    shell: str


CREDENTIALS = os.environ["CREDENTIALS_DIRECTORY"]
REMOTE_AUTH_AGENT = os.environ["CHATGPT_SHELL_REMOTE_AUTH_AGENT"]
LOCAL = [os.environ["CHATGPT_SHELL_BASH"], "-lc"]
COMMAND_PATH = os.environ["CHATGPT_SHELL_COMMAND_PATH"]
SSH = [
    "ssh",
    "-oBatchMode=yes",
    "-oConnectTimeout=5",
    "-oIdentitiesOnly=yes",
    "-oStrictHostKeyChecking=yes",
    f"-oUserKnownHostsFile={os.environ.get('CHATGPT_SHELL_KNOWN_HOSTS', f'{CREDENTIALS}/chatgpt-shell-known-hosts')}",
]
LOCAL_HOST = os.environ["CHATGPT_SHELL_LOCAL_HOST"]
REMOTE_TARGETS = {name: RemoteTarget(**target) for name, target in json.loads(os.environ["CHATGPT_SHELL_REMOTE_TARGETS"]).items()}
if not LOCAL_HOST or LOCAL_HOST in REMOTE_TARGETS:
    raise RuntimeError("local host must be nonempty and distinct from remote targets")

# The runtime Literal is also the MCP tool schema: only Nix-configured hosts are accepted.
Host = Literal[LOCAL_HOST, *REMOTE_TARGETS]

_ALLOWED_ENV = {
    "GH_TOKEN",
    "HOME",
    "LANG",
    "LANGUAGE",
    "NIX_CONFIG",
    "NIX_PATH",
    "PATH",
    "TZ",
}
COMMAND_ENV = {key: value for key, value in os.environ.items() if key in _ALLOWED_ENV or key.startswith("LC_")}
HERDR_LOCAL = os.environ.get("CHATGPT_SHELL_HC", "hc")
WORKER_ENV = json.loads(os.environ["CHATGPT_SHELL_WORKER_ENV"])
HERDR_SESSION = WORKER_ENV["HC_SESSION"]
WORKER_USER = os.environ["CHATGPT_SHELL_WORKER"]
RUN0 = os.environ.get("CHATGPT_SHELL_RUN0", "run0")
SYSTEMCTL = os.path.join(os.path.dirname(RUN0), "systemctl")


def _require_local_herdr(host: Host) -> None:
    """Reject attempts to treat existing SSH targets as Herdr Core servers."""
    if host != LOCAL_HOST:
        raise ValueError(f"Herdr sessions are hosted on {LOCAL_HOST}; remote commands use SSH")


def _herdr_argv(host: Host, arguments: list[str], *, unit_name: str | None = None) -> list[str]:
    """Herdr Core lives only on the server, under its restricted worker identity."""
    _require_local_herdr(host)
    command = f"unset SSH_AUTH_SOCK GH_TOKEN; export HC_SESSION={shlex.quote(HERDR_SESSION)}; exec {shlex.join([HERDR_LOCAL, *arguments])}"
    return _build_argv(LOCAL_HOST, command, unit_name=unit_name)


async def _interrupt_worker_unit(unit_name: str) -> None:
    """Send SIGINT to the actual Core CLI process, not its run0 client."""
    process = await asyncio.create_subprocess_exec(
        RUN0,
        "--non-interactive",
        "--pipe",
        SYSTEMCTL,
        "kill",
        "--signal=SIGINT",
        "--kill-whom=main",
        f"{unit_name}.service",
        stdin=asyncio.subprocess.DEVNULL,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )
    try:
        _, stderr = await asyncio.wait_for(process.communicate(), timeout=5)
    except TimeoutError:
        process.kill()
        await process.wait()
        raise RuntimeError("Core worker interruption timed out") from None
    if process.returncode != 0:
        raise RuntimeError(f"Core worker interruption failed: {stderr.decode(errors='replace')[:1024]}")


async def _herdr(host: Host, arguments: list[str], *, stdin: str | None = None) -> dict[str, object]:
    """Invoke the native Herdr CLI with a bounded response and no privileged agent forwarding."""
    unit_name = f"chatgpt-hc-{uuid.uuid4().hex}" if arguments[0] == "exec" else None
    process = await asyncio.create_subprocess_exec(
        *_herdr_argv(host, arguments, unit_name=unit_name),
        stdin=asyncio.subprocess.PIPE if stdin is not None else asyncio.subprocess.DEVNULL,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
        env={
            **{key: value for key, value in _command_env(host).items() if key not in ("SSH_AUTH_SOCK", "GH_TOKEN")},
            **{key: value for key, value in os.environ.items() if key.startswith("XDG_")},
        },
    )
    try:
        stdout, stderr = await asyncio.wait_for(
            process.communicate(stdin.encode() if stdin is not None else None),
            timeout=HERDR_EXEC_TIMEOUT_SECONDS + 20 if arguments[0] == "exec" else 20,
        )
    except asyncio.CancelledError:
        # run0 runs the Core CLI in a separate service. Signalling only the
        # gateway's run0 client leaves the Core-owned command running.
        try:
            if unit_name is not None:
                await _interrupt_worker_unit(unit_name)
            else:
                with suppress(ProcessLookupError):
                    process.send_signal(signal.SIGINT)
            await asyncio.wait_for(process.wait(), timeout=CANCEL_GRACE_SECONDS)
        except (RuntimeError, TimeoutError) as exc:
            process.kill()
            await process.wait()
            raise RuntimeError("Core command cancellation was not confirmed") from exc
        raise
    except TimeoutError:
        process.kill()
        await process.wait()
        raise RuntimeError("Herdr did not respond before its execution deadline") from None
    if process.returncode != 0:
        raise RuntimeError(f"Herdr failed: {stderr.decode(errors='replace')[:4096]}")
    try:
        return json.loads(stdout)
    except (ValueError, UnicodeDecodeError) as exc:
        raise RuntimeError("Herdr returned an invalid response") from exc


def _command_env(host: Host, *, elevated: bool = False) -> dict[str, str]:
    """Keep credential forwarding separate from ordinary remote SSH commands."""
    environment = {key: value for key, value in COMMAND_ENV.items() if key not in ("SSH_AUTH_SOCK", "GH_TOKEN")}
    if elevated and host == "nixos-arm-parallels":
        environment["SSH_AUTH_SOCK"] = REMOTE_AUTH_AGENT
    return environment


mcp = MCPServer("chatgpt-shell")


@dataclass
class OutputBuffer:
    """Retain bounded command output for later retrieval."""

    data: bytearray = field(default_factory=bytearray)
    omitted: int = 0

    def append(self, chunk: bytes) -> None:
        """Append output without exceeding the retained byte limit."""
        combined = self.data + chunk
        if self.omitted or len(combined) > MAX_OUTPUT_BYTES:
            self.omitted += max(0, len(combined) - MAX_OUTPUT_BYTES)
            self.data[:] = combined[:OUTPUT_HEAD_BYTES] + combined[-OUTPUT_TAIL_BYTES:]
        else:
            self.data[:] = combined

    def drain(self) -> tuple[str, bool, int]:
        """Return buffered output and clear the stored chunks."""
        raw = bytes(self.data)
        omitted = self.omitted
        self.data.clear()
        self.omitted = 0

        if omitted:
            marker = f"\n... {omitted} bytes omitted ...\n".encode()
            raw = raw[:OUTPUT_HEAD_BYTES] + marker + raw[OUTPUT_HEAD_BYTES:]
        return raw.decode(errors="replace"), bool(omitted), omitted


@dataclass
class Job:
    """Track the lifecycle and result of a shell command."""

    request_id: str
    host: Host
    output: OutputBuffer = field(default_factory=OutputBuffer)
    started_at: float = field(default_factory=time.monotonic)
    process: asyncio.subprocess.Process | None = None
    task: asyncio.Task[None] | None = None
    target_pid: int | None = None
    exit_code: int | None = None
    error: str | None = None
    completed_at: float | None = None
    cancel_requested: bool = False
    awaiting_approval: bool = False
    elevated: bool = False
    core_truncated: bool = False


jobs: dict[str, Job] = {}


def _validate_wait_seconds(wait_seconds: float) -> float:
    value = float(wait_seconds)
    if not 0 <= value <= MAX_WAIT_SECONDS:
        raise ValueError(f"wait_seconds must be between 0 and {MAX_WAIT_SECONDS:g}")
    return value


def _validate_cwd(cwd: str | None) -> str | None:
    if cwd is not None and ("\0" in cwd or not PurePosixPath(cwd).is_absolute()):
        raise ValueError("cwd must be an absolute path")
    return cwd


def _worker_command(script: str, unit_name: str | None = None) -> str:
    """Enter the server's restricted identity before interpreting an agent script."""
    arguments = [
        RUN0,
        "--non-interactive",
        "--pipe",
        *([f"--unit={unit_name}"] if unit_name else []),
        f"--user={WORKER_USER}",
        f"--chdir={WORKER_ENV['HOME']}",
        *(f"--setenv={key}={value}" for key, value in WORKER_ENV.items()),
        f"--setenv=PATH={COMMAND_PATH}",
        "--",
        "bash",
        "-c",
        script,
    ]
    return shlex.join(arguments)


def _build_argv(host: Host, script: str, *, unit_name: str | None = None) -> list[str]:
    """Run server commands in Herdr's worker; other hosts use existing SSH targets."""
    if host == LOCAL_HOST:
        return [
            *LOCAL,
            f"export PATH={shlex.quote(COMMAND_PATH)}:$PATH\nexec {_worker_command(script, unit_name)}",
        ]
    target = REMOTE_TARGETS[host]
    remote_command = f"exec {target.shell} -lc {shlex.quote(script)}"
    if unit_name is not None:
        remote_command = f"chatgpt-shell-run {unit_name} {remote_command}"
    return [
        *SSH,
        "-oForwardAgent=no",
        "-i",
        f"{CREDENTIALS}/{target.credential}",
        target.ssh_target,
        remote_command,
    ]


def _build_elevated_argv(host: Host, script: str) -> list[str]:
    """Reach the trusted controller identity, never the unprivileged worker."""
    if host == LOCAL_HOST:
        return [
            *LOCAL,
            f"export PATH={shlex.quote(COMMAND_PATH)}:$PATH\n{script}",
        ]
    if host != "nixos-arm-parallels":
        raise PermissionError(f"elevation broker unavailable on {host}")
    return [
        *SSH,
        "-oForwardAgent=yes",
        "-i",
        f"{CREDENTIALS}/chatgpt-shell-nixos-arm-parallels",
        f"{os.environ['CHATGPT_SHELL_PRIMARY_USER']}@{REMOTE_TARGETS[host].ssh_target.split('@', 1)[1]}",
        f"exec {REMOTE_TARGETS[host].shell} -lc {shlex.quote(script)}",
    ]


def _command_script(command: str, cwd: str | None, marker: str | None) -> str:
    lines = []
    if marker is not None:
        lines.append(f"printf '%s%s\\n' {shlex.quote(marker)} \"$$\"")
    lines.extend(
        [
            f"cd -- {shlex.quote(cwd)} || exit 125" if cwd else 'cd -- "$HOME" || exit 125',
            command,
        ]
    )
    return "\n".join(lines)


async def _read_output(job: Job, marker: str | None) -> None:
    assert job.process is not None
    assert job.process.stdout is not None
    if marker is None:
        while chunk := await job.process.stdout.read(64 * 1024):
            job.output.append(chunk)
        return
    marker_bytes = marker.encode()

    while line := await job.process.stdout.readline():
        if line.startswith(marker_bytes):
            try:
                job.target_pid = int(line[len(marker_bytes) :].strip())
            except ValueError:
                job.output.append(line)
            break
        job.output.append(line)
    else:
        return

    while chunk := await job.process.stdout.read(64 * 1024):
        job.output.append(chunk)


async def _write_stdin(process: asyncio.subprocess.Process, stdin: str | None) -> None:
    if stdin is None or process.stdin is None:
        return
    try:
        process.stdin.write(stdin.encode())
        await process.stdin.drain()
    except (BrokenPipeError, ConnectionResetError):
        pass
    finally:
        process.stdin.close()
        with suppress(BrokenPipeError, ConnectionResetError):
            await process.stdin.wait_closed()


async def _run_herdr_exec(job: Job, command: str, cwd: str | None, stdin: str | None) -> None:
    """Use Core's exact process streams for ordinary commands, not PTY snapshots."""
    arguments = ["exec", "--json"]
    if stdin is not None:
        arguments.append("--stdin")
    arguments.extend(
        [
            "--timeout",
            str(HERDR_EXEC_TIMEOUT_SECONDS),
            "--cwd",
            cwd or WORKER_ENV["HOME"],
            "bash",
            "-c",
            "exec 2>&1\n" + command,
        ]
    )
    response = await _herdr(job.host, arguments, stdin=stdin)
    for stream in ("stdout", "stderr"):
        encoded = response.get(stream)
        if not isinstance(encoded, str):
            raise RuntimeError("Herdr returned an invalid exec response")
        job.output.append(base64.b64decode(encoded, validate=True))
    code = response.get("code")
    if not isinstance(code, int):
        raise RuntimeError("Herdr did not return an exit code")
    job.exit_code = code
    if response.get("truncated"):
        job.core_truncated = True
        job.output.append(b"\n[Herdr truncated the exec output]\n")


async def _run(job: Job, command: str, cwd: str | None, stdin: str | None) -> None:
    marker = f"__CHATGPT_SHELL_PID_{job.request_id}__="
    target_identity = "root" if job.elevated else WORKER_USER
    if not job.elevated and job.host in REMOTE_TARGETS:
        target_identity = REMOTE_TARGETS[job.host].ssh_target.split("@", 1)[0]
    try:
        job.awaiting_approval = True
        await authorization.authorize(
            job.request_id,
            job.host,
            "elevation" if job.elevated else "commands",
            command,
            cwd,
            stdin,
            target_identity=target_identity,
        )
        job.awaiting_approval = False
        if job.host == LOCAL_HOST and not job.elevated:
            await _run_herdr_exec(job, command, cwd, stdin)
            return
        named_remote_unit = job.host == "nixos-arm-parallels" and not job.elevated
        output_marker = None if named_remote_unit else marker
        script = _command_script(command, cwd, output_marker)
        if named_remote_unit:
            argv = _build_argv(job.host, script, unit_name=job.request_id)
        else:
            build = _build_elevated_argv if job.elevated else _build_argv
            argv = build(job.host, script)
        job.process = await asyncio.create_subprocess_exec(
            *argv,
            stdin=asyncio.subprocess.PIPE if stdin is not None else asyncio.subprocess.DEVNULL,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.STDOUT,
            env=_command_env(job.host, elevated=job.elevated),
            start_new_session=True,
        )
        reader = asyncio.create_task(_read_output(job, output_marker))
        writer = asyncio.create_task(_write_stdin(job.process, stdin))
        job.exit_code = await job.process.wait()
        await writer
        try:
            await asyncio.wait_for(asyncio.shield(reader), timeout=1)
        except TimeoutError:
            # Detached children may keep stdout open after the shell exits.
            pipe = job.process._transport.get_pipe_transport(1)
            if pipe is not None:
                pipe.close()
            await reader
    except Exception as exc:
        job.error = str(exc)
    finally:
        job.awaiting_approval = False
        job.completed_at = time.monotonic()


def _payload(job: Job, *, include_output: bool = True) -> dict[str, object]:
    end = job.completed_at or time.monotonic()
    if job.completed_at is None:
        status = "awaiting_approval" if job.awaiting_approval else "running"
    elif job.error:
        status = "failed"
    elif job.cancel_requested:
        status = "cancelled"
    else:
        status = "completed"
    payload: dict[str, object] = {
        "status": status,
        "success": job.completed_at is not None and not job.cancel_requested and job.error is None and job.exit_code == 0,
        "host": job.host,
        "duration_ms": round((end - job.started_at) * 1000),
    }
    if include_output:
        output, truncated, omitted = job.output.drain()
        payload.update(output=output, output_truncated=truncated or job.core_truncated)
        if omitted:
            payload["omitted_bytes"] = omitted
    if job.awaiting_approval:
        payload["approval_id"] = job.request_id
    if job.target_pid is not None and job.host != "nixos-arm-parallels":
        payload["pid"] = job.target_pid
    payload["request_id"] = job.request_id
    if job.exit_code is not None:
        payload["exit_code"] = job.exit_code
    if job.error is not None:
        payload["error"] = job.error
    return payload


async def _result(job: Job, wait_seconds: float) -> dict[str, object]:
    if job.task is not None and not job.task.done() and wait_seconds:
        with suppress(TimeoutError):
            await asyncio.wait_for(asyncio.shield(job.task), timeout=wait_seconds)
    return _payload(job)


def _prune_jobs() -> None:
    now = time.monotonic()
    for request_id, job in list(jobs.items()):
        if job.completed_at is not None and now - job.completed_at >= JOB_RETENTION_SECONDS:
            jobs.pop(request_id)


async def _signal_target(job: Job, sig: str) -> None:
    if job.elevated:
        script = shlex.join(
            [
                "run0",
                "--non-interactive",
                "--pipe",
                "systemctl",
                "kill",
                f"--signal={sig}",
                "--kill-whom=all",
                f"chatgpt-shell-{job.request_id}.service",
            ]
        )
        argv = _build_elevated_argv(job.host, script)
    elif job.host == "nixos-arm-parallels":
        # The PID namespace prevents external PID signalling. Kill the entire
        # named unit: TERM may only stop a shell's current child, allowing its
        # following commands to run before the shell itself exits.
        target = REMOTE_TARGETS[job.host]
        argv = [
            *SSH,
            "-oForwardAgent=no",
            "-i",
            f"{CREDENTIALS}/{target.credential}",
            target.ssh_target,
            f"chatgpt-shell-cancel {job.request_id} KILL",
        ]
    elif job.target_pid is not None:
        script = f"""
descendants() {{
  for child in $(pgrep -P "$1" 2>/dev/null); do
    printf '%s\n' "$child"
    descendants "$child"
  done
}}
children=$(descendants {job.target_pid})
kill -s {sig} {job.target_pid} $children 2>/dev/null || true
"""
        argv = _build_argv(job.host, script)
    else:
        return

    try:
        process = await asyncio.create_subprocess_exec(
            *argv,
            stdin=asyncio.subprocess.DEVNULL,
            stdout=asyncio.subprocess.DEVNULL,
            stderr=asyncio.subprocess.DEVNULL,
            env=_command_env(job.host, elevated=job.elevated),
            start_new_session=True,
        )
        await asyncio.wait_for(
            process.wait(),
            timeout=8 if job.host == "nixos-arm-parallels" and not job.elevated else 5,
        )
        if job.host == "nixos-arm-parallels" and not job.elevated and process.returncode != 0:
            raise RuntimeError("Remote command interruption was not confirmed")
    except Exception:
        if job.host == "nixos-arm-parallels" and not job.elevated:
            raise


@mcp.tool()
async def session_start(
    host: Host,
    command: str,
    cwd: str | None = None,
) -> dict[str, object]:
    """Start an observable persistent Herdr terminal on a configured host.

    The server owns every Herdr terminal; remote hosts use the existing SSH
    command path instead. This is a normal-user shell, not a privileged approval.
    """
    cwd = _validate_cwd(cwd)
    _require_local_herdr(host)
    session_name = f"chatgpt-{uuid.uuid4().hex[:12]}"
    arguments = [
        "run",
        "--bg",
        "--json",
        "--name",
        session_name,
        "--label",
        "origin=chatgpt-shell",
        "--no-parent",
    ]
    if cwd is not None:
        arguments.extend(["--cwd", cwd])
    arguments.extend(["bash", "-c", command])
    await authorization.authorize(
        uuid.uuid4().hex,
        host,
        "commands",
        shlex.join(arguments),
        cwd,
        session=session_name,
        target_identity=WORKER_USER,
    )
    result = await _herdr(host, arguments)
    address = result.get("address")
    if not isinstance(address, str):
        raise RuntimeError("Herdr did not return a terminal address")
    try:
        metadata = await _herdr(host, ["get", "--json", address])
        authorization.register_terminal(address, session_name, metadata)
    except (Exception, asyncio.CancelledError):
        # Do not leave an untracked command running when registration fails.
        with suppress(Exception):
            await _herdr(host, ["kill", "--json", address])
        raise
    return {"host": host, "session": HERDR_SESSION, **result}


@mcp.tool()
async def session_list(host: Host) -> dict[str, object]:
    """List all terminals within the server worker's Herdr core."""
    _require_local_herdr(host)
    return await _herdr(host, ["ls", "--all", "--json"])


@mcp.tool()
async def session_read(host: Host, terminal: str, lines: int = 100) -> dict[str, object]:
    """Read a Herdr terminal's current screen and scrollback."""
    if not 0 <= lines <= 2000:
        raise ValueError("lines must be between 0 and 2000")
    _require_local_herdr(host)
    return await _herdr(host, ["read", "--json", "--lines", str(lines), terminal])


async def _managed_session_action(host: Host, terminal: str, action: str) -> dict[str, object]:
    """Allow only recorded agent terminals through the approval broker."""
    _require_local_herdr(host)
    metadata = await _herdr(host, ["get", "--json", terminal])
    if not authorization.owns_terminal(terminal, metadata):
        raise PermissionError("terminal is not an agent-managed workspace")
    arguments = [action, "--json", terminal]
    await authorization.authorize(
        uuid.uuid4().hex,
        host,
        "commands",
        shlex.join(arguments),
        None,
        session=metadata["name"],
        target_identity=WORKER_USER,
    )
    # An operator approval may take minutes; reject replacement sessions.
    current = await _herdr(host, ["get", "--json", terminal])
    if not authorization.owns_terminal(terminal, current):
        raise PermissionError("terminal identity changed during approval")
    result = await _herdr(host, arguments)
    if action == "kill":
        authorization.release_terminal(terminal)
    return result


@mcp.tool()
async def session_interrupt(host: Host, terminal: str) -> dict[str, object]:
    """Interrupt an agent-managed terminal subject to its scoped command policy."""
    return await _managed_session_action(host, terminal, "interrupt")


@mcp.tool()
async def session_kill(host: Host, terminal: str) -> dict[str, object]:
    """Terminate an agent-managed terminal subject to its scoped command policy."""
    return await _managed_session_action(host, terminal, "kill")


@mcp.tool()
async def shell_exec(
    host: Host,
    command: str,
    cwd: str | None = None,
    wait_seconds: float = WAIT_SECONDS,
    stdin: str | None = None,
) -> dict[str, object]:
    """Run on the server's restricted worker or a configured remote SSH host.

    Remote SSH commands retain their configured user identity and are not
    Herdr-backed; only server commands get persistent terminal addresses.
    Use cwd (an absolute path) instead of prepending cd; default is the user's home.
    Pass multiline input via stdin, not shell interpolation. wait_seconds (0-30)
    bounds the wait for both startup and completion; 0 returns immediately.
    A running result has a request_id for shell_result or shell_cancel.
    Check success or exit_code, not status='completed', for command success.
    Stdout and stderr are combined and bounded. Server Core exec replies
    contain exact output after completion; use sessions for live PTY output.
    """
    cwd = _validate_cwd(cwd)
    wait_seconds = _validate_wait_seconds(wait_seconds)

    _prune_jobs()
    if len(jobs) >= MAX_JOBS:
        finished = next((job for job in jobs.values() if job.completed_at is not None), None)
        if finished is None:
            raise RuntimeError("too many active jobs")
        jobs.pop(finished.request_id, None)

    request_id = uuid.uuid4().hex
    job = Job(
        request_id=request_id,
        host=host,
        awaiting_approval=authorization.effective(host, "commands") == "ask",
    )
    jobs[request_id] = job
    job.task = asyncio.create_task(_run(job, command, cwd, stdin))
    return await _result(job, wait_seconds)


@mcp.tool()
async def shell_elevated_exec(
    host: Host,
    argv: list[str],
    cwd: str | None = None,
    wait_seconds: float = WAIT_SECONDS,
) -> dict[str, object]:
    """Run an explicitly approved native Linux run0 operation.

    Exact argv values are shell-quoted before reaching run0. The operating
    system independently authorizes the elevated transient service.
    """
    cwd = _validate_cwd(cwd)
    wait_seconds = _validate_wait_seconds(wait_seconds)
    if host not in (LOCAL_HOST, "nixos-arm-parallels"):
        raise PermissionError(f"elevation broker unavailable on {host}")
    if not argv or any(not item or "\0" in item for item in argv):
        raise ValueError("argv must contain non-empty arguments without NUL bytes")
    _prune_jobs()
    if len(jobs) >= MAX_JOBS and all(item.completed_at is None for item in jobs.values()):
        raise RuntimeError("too many active jobs")
    if len(jobs) >= MAX_JOBS:
        finished = next(item for item in jobs.values() if item.completed_at is not None)
        jobs.pop(finished.request_id)

    job = Job(
        request_id=uuid.uuid4().hex,
        host=host,
        elevated=True,
        awaiting_approval=authorization.effective(host, "elevation") == "ask",
    )
    jobs[job.request_id] = job
    run0_args = ["run0", "--non-interactive", "--pipe", f"--unit=chatgpt-shell-{job.request_id}"]
    if cwd:
        run0_args.append(f"--chdir={cwd}")
    job.task = asyncio.create_task(_run(job, shlex.join([*run0_args, "--", *argv]), cwd, None))
    return await _result(job, wait_seconds)


@mcp.tool()
async def shell_result(
    request_id: str,
    wait_seconds: float = WAIT_SECONDS,
) -> dict[str, object]:
    """Wait up to wait_seconds (0-30) and return new output for a tracked job.

    Completed jobs remain available for a short period; each read drains their
    buffered output. Use shell_jobs to recover an unknown request_id.
    """
    _prune_jobs()
    job = jobs.get(request_id)
    if job is None:
        raise ValueError("unknown or expired request_id")
    return await _result(job, _validate_wait_seconds(wait_seconds))


@mcp.tool()
async def shell_jobs() -> list[dict[str, object]]:
    """List running and recent commands with request IDs for recovery.

    Jobs expire 30 minutes after completion (or sooner under capacity pressure).
    Listing does not consume their buffered output.
    """
    _prune_jobs()
    return [_payload(job, include_output=False) for job in jobs.values()]


@mcp.tool()
async def shell_cancel(request_id: str) -> dict[str, object]:
    """Stop a tracked command and its descendants; return the final result."""
    _prune_jobs()
    job = jobs.get(request_id)
    if job is None:
        raise ValueError("unknown or expired request_id")
    if job.completed_at is not None:
        return _payload(job)

    if job.process is not None and job.process.returncode is not None:
        if job.task is not None:
            await job.task
        return _payload(job)

    job.cancel_requested = True
    if job.process is None and job.task is not None:
        job.task.cancel()
        with suppress(asyncio.CancelledError):
            await job.task
        return _payload(job)
    try:
        await _signal_target(job, "TERM")
        if job.task is not None and not job.task.done():
            try:
                await asyncio.wait_for(asyncio.shield(job.task), timeout=CANCEL_GRACE_SECONDS)
            except TimeoutError:
                await _signal_target(job, "KILL")
    except Exception:
        job.cancel_requested = False
        raise

    if job.task is not None and not job.task.done() and job.process is not None:
        with suppress(ProcessLookupError, PermissionError):
            os.killpg(job.process.pid, signal.SIGKILL)
        await job.task

    return _payload(job)


if __name__ == "__main__":
    mcp.run()
