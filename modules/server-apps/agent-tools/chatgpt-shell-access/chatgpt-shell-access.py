"""Provide bounded shell execution on explicitly configured hosts."""

import asyncio
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


@dataclass(frozen=True)
class RemoteTarget:
    """Connection and agent-forwarding settings for a remote host."""

    ssh_target: str
    credential: str
    shell: str
    forwardAgent: bool  # noqa: N815 - matches the serialized remote target schema


CREDENTIALS = os.environ["CREDENTIALS_DIRECTORY"]
SUDO_AGENT = os.environ["SSH_AUTH_SOCK"]
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
HERDR_SESSION = os.environ.get("CHATGPT_SHELL_HC_SESSION", "chatgpt-shell")
WORKER_USER = os.environ.get("CHATGPT_SHELL_WORKER", "herdr-worker")
RUN0 = os.environ.get("CHATGPT_SHELL_RUN0", "run0")
HERDR_COMMANDS = os.environ.get("CHATGPT_SHELL_HERDR_COMMANDS", "") == "1"


def _herdr_argv(host: Host, arguments: list[str]) -> list[str]:
    """Use the restricted SSH worker for native Herdr commands on every host."""
    command = (
        "unset SSH_AUTH_SOCK GH_TOKEN; "
        f"export HC_SESSION={shlex.quote(HERDR_SESSION)}; "
        f"exec {shlex.join([HERDR_LOCAL if host == LOCAL_HOST else 'hc', *arguments])}"
    )
    return _build_argv(host, command)


async def _herdr(host: Host, arguments: list[str]) -> dict[str, object]:
    """Invoke the native Herdr CLI with a bounded response and no privileged agent forwarding."""
    process = await asyncio.create_subprocess_exec(
        *_herdr_argv(host, arguments),
        stdin=asyncio.subprocess.DEVNULL,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
        env={
            **{key: value for key, value in _command_env(host).items() if key not in ("SSH_AUTH_SOCK", "GH_TOKEN")},
            **{key: value for key, value in os.environ.items() if key.startswith("XDG_")},
        },
    )
    try:
        stdout, stderr = await asyncio.wait_for(process.communicate(), timeout=20)
    except TimeoutError:
        process.kill()
        await process.wait()
        raise RuntimeError("Herdr did not respond within 20 seconds") from None
    if process.returncode != 0:
        raise RuntimeError(f"Herdr failed: {stderr.decode(errors='replace')[:4096]}")
    try:
        return json.loads(stdout)
    except (ValueError, UnicodeDecodeError) as exc:
        raise RuntimeError("Herdr returned an invalid response") from exc


def _command_env(host: Host, *, elevated: bool = False) -> dict[str, str]:
    """Give the trusted launcher only the SSH signature needed to enter the worker."""
    environment = {key: value for key, value in COMMAND_ENV.items() if key not in ("SSH_AUTH_SOCK", "GH_TOKEN")}
    if host == LOCAL_HOST:
        environment["SSH_AUTH_SOCK"] = SUDO_AGENT
    elif host == "nixos-arm-parallels":
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
    herdr_terminal: str | None = None
    herdr_screen: str = ""
    herdr_starting: bool = False
    herdr_ready: asyncio.Event = field(default_factory=asyncio.Event)


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


def _worker_command(host: Host, script: str) -> str:
    """Enter a non-admin identity before interpreting any agent-provided script."""
    if host == "mac":
        return shlex.join(
            [
                "sudo",
                "-n",
                "-H",
                "-u",
                WORKER_USER,
                "--",
                "/usr/bin/env",
                f"HC_SESSION={HERDR_SESSION}",
                "/bin/zsh",
                "-lc",
                script,
            ]
        )
    arguments = [
        RUN0 if host == LOCAL_HOST else "run0",
        "--non-interactive",
        "--pipe",
        f"--user={WORKER_USER}",
        "--chdir=/tmp",
        "--setenv=HOME=/var/lib/herdr-worker",
        f"--setenv=HC_SESSION={HERDR_SESSION}",
        "--setenv=XDG_RUNTIME_DIR=/run/herdr-worker",
        "--setenv=XDG_CONFIG_HOME=/var/lib/herdr-worker/.config",
        "--setenv=XDG_STATE_HOME=/var/lib/herdr-worker/.local/state",
    ]
    if host == LOCAL_HOST:
        arguments.append(f"--setenv=PATH={COMMAND_PATH}")
    arguments.extend(["--", "bash", "-lc", script])
    return shlex.join(arguments)


def _build_argv(host: Host, script: str) -> list[str]:
    """Use native authorization only to launch commands under a restricted user."""
    worker_command = _worker_command(host, script)
    if host == LOCAL_HOST:
        return [
            *LOCAL,
            f"export PATH={shlex.quote(COMMAND_PATH)}:$PATH\nexport SSH_AUTH_SOCK={shlex.quote(SUDO_AGENT)}\nexec {worker_command}",
        ]
    target = REMOTE_TARGETS[host]
    return [
        *SSH,
        f"-oForwardAgent={'yes' if target.forwardAgent else 'no'}",
        "-i",
        f"{CREDENTIALS}/{target.credential}",
        target.ssh_target,
        f"cd /tmp && exec {target.shell} -lc {shlex.quote(worker_command)}",
    ]


def _build_elevated_argv(host: Host, script: str) -> list[str]:
    """Reach the trusted controller identity, never the unprivileged worker."""
    if host == LOCAL_HOST:
        return [
            *LOCAL,
            f"export PATH={shlex.quote(COMMAND_PATH)}:$PATH\nexport SSH_AUTH_SOCK={shlex.quote(SUDO_AGENT)}\n{script}",
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


def _command_script(command: str, cwd: str | None, marker: str) -> str:
    return "\n".join(
        [
            f"printf '%s%s\\n' {shlex.quote(marker)} \"$$\"",
            f"cd -- {shlex.quote(cwd)} || exit 125" if cwd else 'cd -- "$HOME" || exit 125',
            command,
        ]
    )


async def _read_output(job: Job, marker: str) -> None:
    assert job.process is not None
    assert job.process.stdout is not None
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


async def _run_herdr(job: Job, command: str, cwd: str | None) -> None:
    """Use Herdr's native persistent PTY for observable, interruptible commands."""
    name = f"chatgpt-{job.request_id[:12]}"
    arguments = [
        "run",
        "--bg",
        "--json",
        "--name",
        name,
        "--label",
        "origin=chatgpt-shell",
        "--no-parent",
        "--cwd",
        cwd or ("/Users/herdr-worker" if job.host == "mac" else "/var/lib/herdr-worker"),
        "/bin/zsh" if job.host == "mac" else "bash",
        "-lc",
        command,
    ]
    job.herdr_starting = True
    try:
        created = await _herdr(job.host, arguments)
        address = created.get("address")
        if not isinstance(address, str):
            raise RuntimeError("Herdr did not return a terminal address")
        job.herdr_terminal = address
    finally:
        job.herdr_starting = False
        job.herdr_ready.set()
    while True:
        snapshot = await _herdr(job.host, ["get", "--json", address])
        screen = await _herdr(job.host, ["read", "--json", "--lines", "2000", address])
        current = screen.get("text")
        if not isinstance(current, str):
            raise RuntimeError("Herdr returned invalid terminal output")
        if current.startswith(job.herdr_screen):
            delta = current[len(job.herdr_screen) :]
        elif current == job.herdr_screen:
            delta = ""
        else:
            # Readbacks are terminal snapshots, not raw stdout. Reuse overlap
            # when the scrollback window has moved to avoid duplicate output.
            overlap = next(
                (
                    size
                    for size in range(min(len(job.herdr_screen), len(current), 4096), 0, -1)
                    if job.herdr_screen.endswith(current[:size])
                ),
                0,
            )
            delta = current[overlap:] if overlap else "\n" + current
        if delta:
            job.output.append(delta.encode())
        job.herdr_screen = current

        if snapshot.get("state") == "finished":
            code = snapshot.get("exit_code")
            job.exit_code = int(code) if code is not None else 128
            return
        if snapshot.get("state") != "live":
            raise RuntimeError(f"Herdr terminal lost: {snapshot.get('state')}")
        await asyncio.sleep(0.5)


async def _run(job: Job, command: str, cwd: str | None, stdin: str | None) -> None:
    marker = f"__CHATGPT_SHELL_PID_{job.request_id}__="
    try:
        job.awaiting_approval = True
        await authorization.authorize(
            job.request_id,
            job.host,
            "elevation" if job.elevated else "commands",
            command,
            cwd,
            stdin,
        )
        job.awaiting_approval = False
        if HERDR_COMMANDS and not job.elevated and stdin is None:
            await _run_herdr(job, command, cwd)
            return
        build = _build_elevated_argv if job.elevated else _build_argv
        job.process = await asyncio.create_subprocess_exec(
            *build(job.host, _command_script(command, cwd, marker)),
            stdin=asyncio.subprocess.PIPE if stdin is not None else asyncio.subprocess.DEVNULL,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.STDOUT,
            env=_command_env(job.host, elevated=job.elevated),
            start_new_session=True,
        )
        reader = asyncio.create_task(_read_output(job, marker))
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
    elif job.cancel_requested:
        status = "cancelled"
    elif job.error:
        status = "failed"
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
        payload.update(output=output, output_truncated=truncated)
        if omitted:
            payload["omitted_bytes"] = omitted
    if job.awaiting_approval:
        payload["approval_id"] = job.request_id
    if job.herdr_terminal:
        payload["terminal"] = job.herdr_terminal
    if job.target_pid is not None:
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
        build = _build_elevated_argv
    elif job.target_pid is not None:
        build = _build_argv
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
    else:
        return

    try:
        process = await asyncio.create_subprocess_exec(
            *build(job.host, script),
            stdin=asyncio.subprocess.DEVNULL,
            stdout=asyncio.subprocess.DEVNULL,
            stderr=asyncio.subprocess.DEVNULL,
            env=_command_env(job.host, elevated=job.elevated),
            start_new_session=True,
        )
        await asyncio.wait_for(process.wait(), timeout=5)
    except Exception:
        pass


@mcp.tool()
async def session_start(
    host: Host,
    command: str,
    cwd: str | None = None,
) -> dict[str, object]:
    """Start an observable persistent Herdr terminal on a configured host.

    Herdr manages the process and lifetime; connect with hc attach --observe or an
    existing Herdr client. This is a normal-user shell, not a privileged approval.
    """
    cwd = _validate_cwd(cwd)
    if authorization.effective(host, "commands") != "automatic":
        raise PermissionError("interactive session creation requires automatic command permission")
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
    arguments.extend(["bash" if host != "mac" else "/bin/zsh", "-lc", command])
    result = await _herdr(host, arguments)
    return {"host": host, "session": HERDR_SESSION, **result}


@mcp.tool()
async def session_list(host: Host) -> dict[str, object]:
    """List all terminals within the restricted worker's Herdr core."""
    return await _herdr(host, ["ls", "--all", "--json"])


@mcp.tool()
async def session_read(host: Host, terminal: str, lines: int = 100) -> dict[str, object]:
    """Read a Herdr terminal's current screen and scrollback."""
    if not 0 <= lines <= 2000:
        raise ValueError("lines must be between 0 and 2000")
    return await _herdr(host, ["read", "--json", "--lines", str(lines), terminal])


@mcp.tool()
async def session_interrupt(host: Host, terminal: str) -> dict[str, object]:
    """Interrupt a ChatGPT-managed terminal only when command control is enabled."""
    if authorization.effective(host, "commands") != "automatic":
        raise PermissionError("agent terminal mutation is disabled by the command policy")
    return await _herdr(host, ["interrupt", "--json", terminal])


@mcp.tool()
async def session_kill(host: Host, terminal: str) -> dict[str, object]:
    """Terminate a managed terminal only when the command policy permits it."""
    if authorization.effective(host, "commands") != "automatic":
        raise PermissionError("agent terminal mutation is disabled by the command policy")
    return await _herdr(host, ["kill", "--json", terminal])


@mcp.tool()
async def shell_exec(
    host: Host,
    command: str,
    cwd: str | None = None,
    wait_seconds: float = WAIT_SECONDS,
    stdin: str | None = None,
) -> dict[str, object]:
    """Run a submitted command on a permitted host under a restricted identity.

    Use cwd (an absolute path) instead of prepending cd; default is the user's home.
    Pass multiline input via stdin, not shell interpolation. wait_seconds (0-30)
    bounds the wait for both startup and completion; 0 returns immediately.
    A running result has a request_id for shell_result or shell_cancel.
    Check success or exit_code, not status='completed', for command success.
    Stdout and stderr are combined; output is bounded and drained per result.
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
    if job.herdr_starting:
        try:
            await asyncio.wait_for(job.herdr_ready.wait(), timeout=20)
        except TimeoutError:
            if job.task is not None:
                job.task.cancel()
                with suppress(asyncio.CancelledError):
                    await job.task
            return _payload(job)
        if job.completed_at is not None:
            return _payload(job)
    if job.herdr_terminal is not None:
        try:
            await _herdr(job.host, ["interrupt", "--json", job.herdr_terminal])
            if job.task is not None and not job.task.done():
                with suppress(TimeoutError):
                    await asyncio.wait_for(asyncio.shield(job.task), timeout=CANCEL_GRACE_SECONDS)
            if job.task is not None and not job.task.done():
                await _herdr(job.host, ["kill", "--json", job.herdr_terminal])
                await job.task
        except Exception as exc:
            if job.task is not None:
                job.task.cancel()
                with suppress(asyncio.CancelledError):
                    await job.task
            job.error = str(exc)
            job.completed_at = time.monotonic()
        return _payload(job)
    if job.process is None and job.task is not None:
        job.task.cancel()
        with suppress(asyncio.CancelledError):
            await job.task
        return _payload(job)
    await _signal_target(job, "TERM")
    if job.task is not None and not job.task.done():
        try:
            await asyncio.wait_for(asyncio.shield(job.task), timeout=CANCEL_GRACE_SECONDS)
        except TimeoutError:
            await _signal_target(job, "KILL")

    if job.task is not None and not job.task.done() and job.process is not None:
        with suppress(ProcessLookupError, PermissionError):
            os.killpg(job.process.pid, signal.SIGKILL)
        await job.task

    return _payload(job)


if __name__ == "__main__":
    mcp.run()
