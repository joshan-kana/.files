import asyncio
import json
import os
import shlex
import signal
import time
import uuid
from dataclasses import dataclass, field
from pathlib import PurePosixPath
from typing import Literal

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
    ssh_target: str
    credential: str
    shell: str
    sudo: bool


CREDENTIALS = os.environ["CREDENTIALS_DIRECTORY"]
SUDO_AGENT = os.environ["SSH_AUTH_SOCK"]
REMOTE_SUDO_AGENT = os.environ["CHATGPT_SHELL_REMOTE_SUDO_AGENT"]
COMMAND_PATH = os.environ["CHATGPT_SHELL_COMMAND_PATH"]
LOCAL = [
    "/run/wrappers/bin/sudo",
    "-n",
    "-H",
    "-u",
    os.environ["CHATGPT_SHELL_LOCAL_USER"],
    "--",
    os.environ["CHATGPT_SHELL_BASH"],
    "-lc",
]
SSH = [
    "ssh",
    "-oBatchMode=yes",
    "-oConnectTimeout=5",
    "-oIdentitiesOnly=yes",
    "-oStrictHostKeyChecking=yes",
    f"-oUserKnownHostsFile={CREDENTIALS}/chatgpt-shell-known-hosts",
]
LOCAL_HOST = os.environ["CHATGPT_SHELL_LOCAL_HOST"]
REMOTE_TARGETS = {name: RemoteTarget(**target) for name, target in json.loads(os.environ["CHATGPT_SHELL_REMOTE_TARGETS"]).items()}
if not LOCAL_HOST or LOCAL_HOST in REMOTE_TARGETS:
    raise RuntimeError("local host must be nonempty and distinct from remote targets")

# The runtime Literal is also the MCP tool schema: only Nix-configured hosts are accepted.
Host = Literal[tuple([LOCAL_HOST, *REMOTE_TARGETS])]

_ALLOWED_ENV = {
    "GH_TOKEN",
    "LANG",
    "LANGUAGE",
    "NIX_CONFIG",
    "NIX_PATH",
    "PATH",
    "TZ",
}
COMMAND_ENV = {key: value for key, value in os.environ.items() if key in _ALLOWED_ENV or key.startswith("LC_")}


def _command_env(host: Host) -> dict[str, str]:
    environment = COMMAND_ENV.copy()
    if host != LOCAL_HOST and REMOTE_TARGETS[host].sudo:
        environment["SSH_AUTH_SOCK"] = REMOTE_SUDO_AGENT
    return environment


mcp = MCPServer("chatgpt-shell")


@dataclass
class OutputBuffer:
    data: bytearray = field(default_factory=bytearray)
    omitted: int = 0

    def append(self, chunk: bytes) -> None:
        combined = self.data + chunk
        if self.omitted or len(combined) > MAX_OUTPUT_BYTES:
            self.omitted += max(0, len(combined) - MAX_OUTPUT_BYTES)
            self.data[:] = combined[:OUTPUT_HEAD_BYTES] + combined[-OUTPUT_TAIL_BYTES:]
        else:
            self.data[:] = combined

    def drain(self) -> tuple[str, bool, int]:
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


def _build_argv(host: Host, script: str) -> list[str]:
    if host == LOCAL_HOST:
        environment = "\n".join(
            [
                f"export PATH={shlex.quote(COMMAND_PATH)}:$PATH",
                f"export SSH_AUTH_SOCK={shlex.quote(SUDO_AGENT)}",
            ]
        )
        return [*LOCAL, f"{environment}\n{script}"]
    target = REMOTE_TARGETS[host]
    return [
        *SSH,
        f"-oForwardAgent={'yes' if target.sudo else 'no'}",
        "-i",
        f"{CREDENTIALS}/{target.credential}",
        target.ssh_target,
        f"exec {target.shell} -lc {shlex.quote(script)}",
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
        try:
            await process.stdin.wait_closed()
        except (BrokenPipeError, ConnectionResetError):
            pass


async def _run(job: Job, command: str, cwd: str | None, stdin: str | None) -> None:
    marker = f"__CHATGPT_SHELL_PID_{job.request_id}__="
    try:
        job.process = await asyncio.create_subprocess_exec(
            *_build_argv(job.host, _command_script(command, cwd, marker)),
            stdin=asyncio.subprocess.PIPE if stdin is not None else asyncio.subprocess.DEVNULL,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.STDOUT,
            env=_command_env(job.host),
            start_new_session=True,
        )
        reader = asyncio.create_task(_read_output(job, marker))
        writer = asyncio.create_task(_write_stdin(job.process, stdin))
        job.exit_code = await job.process.wait()
        await writer
        await reader
    except Exception as exc:
        job.error = str(exc)
    finally:
        job.completed_at = time.monotonic()


def _payload(job: Job, *, include_output: bool = True) -> dict[str, object]:
    end = job.completed_at or time.monotonic()
    if job.completed_at is None:
        status = "running"
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
        try:
            await asyncio.wait_for(asyncio.shield(job.task), timeout=wait_seconds)
        except TimeoutError:
            pass
    return _payload(job)


def _prune_jobs() -> None:
    now = time.monotonic()
    for request_id, job in list(jobs.items()):
        if job.completed_at is not None and now - job.completed_at >= JOB_RETENTION_SECONDS:
            jobs.pop(request_id)


async def _signal_target(job: Job, sig: str) -> None:
    if job.host == LOCAL_HOST:
        if job.process is None:
            return
        # Signal from the configured user, not the unprivileged MCP service.
        script = f"kill -s {sig} -- -{job.process.pid} 2>/dev/null || true"
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
    else:
        return

    try:
        process = await asyncio.create_subprocess_exec(
            *_build_argv(job.host, script),
            stdin=asyncio.subprocess.DEVNULL,
            stdout=asyncio.subprocess.DEVNULL,
            stderr=asyncio.subprocess.DEVNULL,
            env=_command_env(job.host),
            start_new_session=True,
        )
        await asyncio.wait_for(process.wait(), timeout=5)
    except Exception:
        pass


@mcp.tool()
async def shell_exec(
    host: Host,
    command: str,
    cwd: str | None = None,
    wait_seconds: float = WAIT_SECONDS,
    stdin: str | None = None,
) -> dict[str, object]:
    """Run a command on an allowed host as the configured user.

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
    job = Job(request_id=request_id, host=host)
    jobs[request_id] = job
    job.task = asyncio.create_task(_run(job, command, cwd, stdin))
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

    job.cancel_requested = True
    await _signal_target(job, "TERM")
    if job.task is not None and not job.task.done():
        try:
            await asyncio.wait_for(asyncio.shield(job.task), timeout=CANCEL_GRACE_SECONDS)
        except TimeoutError:
            await _signal_target(job, "KILL")

    if job.task is not None and not job.task.done() and job.process is not None:
        try:
            os.killpg(job.process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        await job.task

    return _payload(job)


if __name__ == "__main__":
    mcp.run()
