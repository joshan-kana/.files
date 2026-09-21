import asyncio
import logging
import os
import re
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
MAX_FILE_BYTES = 4 * 1024 * 1024
MAX_JOBS = 64
WAIT_SECONDS = 10.0
MAX_WAIT_SECONDS = 30.0
FINISHED_TTL_SECONDS = 60 * 60
CANCEL_GRACE_SECONDS = 2.0
Host = Literal["nixos-server", "mac"]

CREDENTIALS = os.environ["CREDENTIALS_DIRECTORY"]
SUDO_AGENT = os.environ["SSH_AUTH_SOCK"]
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
    "-i",
    f"{CREDENTIALS}/chatgpt-shell-mac",
    os.environ["CHATGPT_SHELL_MAC_SSH_TARGET"],
]

_ALLOWED_ENV = {
    "GH_TOKEN",
    "LANG",
    "LANGUAGE",
    "NIX_CONFIG",
    "NIX_PATH",
    "PATH",
    "SSH_AUTH_SOCK",
    "TZ",
}
COMMAND_ENV = {key: value for key, value in os.environ.items() if key in _ALLOWED_ENV or key.startswith("LC_")}

logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")
logger = logging.getLogger("chatgpt-shell")
mcp = MCPServer("chatgpt-shell")


class BoundedOutput:
    def __init__(self) -> None:
        self._data = bytearray()
        self._head = bytearray()
        self._tail = bytearray()
        self._total = 0
        self._truncated = False

    def append(self, chunk: bytes) -> None:
        if not chunk:
            return
        if not self._truncated:
            combined_size = len(self._data) + len(chunk)
            if combined_size <= MAX_OUTPUT_BYTES:
                self._data.extend(chunk)
                self._total = combined_size
                return
            combined = bytes(self._data) + chunk
            self._head.extend(combined[:OUTPUT_HEAD_BYTES])
            self._tail.extend(combined[-OUTPUT_TAIL_BYTES:])
            self._data.clear()
            self._total = len(combined)
            self._truncated = True
            return

        self._total += len(chunk)
        self._tail[:] = (bytes(self._tail) + chunk)[-OUTPUT_TAIL_BYTES:]

    def drain(self) -> tuple[str, bool, int]:
        if self._truncated:
            omitted = self._total - len(self._head) - len(self._tail)
            marker = f"\n... {omitted} bytes omitted ...\n".encode()
            raw = bytes(self._head) + marker + bytes(self._tail)
        else:
            omitted = 0
            raw = bytes(self._data)

        truncated = self._truncated
        self.__init__()
        return raw.decode(errors="replace"), truncated, omitted


@dataclass
class Job:
    request_id: str
    host: Host
    output: BoundedOutput = field(default_factory=BoundedOutput)
    started_at: float = field(default_factory=time.monotonic)
    started_event: asyncio.Event = field(default_factory=asyncio.Event)
    process: asyncio.subprocess.Process | None = None
    task: asyncio.Task[None] | None = None
    target_pid: int | None = None
    status: str = "starting"
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


def _validate_absolute_path(path: str, name: str) -> str:
    if "\0" in path or not PurePosixPath(path).is_absolute():
        raise ValueError(f"{name} must be an absolute path")
    return path


def _build_argv(host: Host, script: str) -> list[str]:
    if host == "nixos-server":
        environment = "\n".join(
            [
                f"export PATH={shlex.quote(COMMAND_PATH)}:$PATH",
                f"export SSH_AUTH_SOCK={shlex.quote(SUDO_AGENT)}",
            ]
        )
        return [*LOCAL, f"{environment}\n{script}"]
    return [*SSH, f"exec /bin/zsh -lc {shlex.quote(script)}"]


def _command_script(host: Host, command: str, cwd: str | None, marker: str) -> str:
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
                job.status = "running"
                logger.info(
                    "request=%s host=%s pid=%s started",
                    job.request_id,
                    job.host,
                    job.target_pid,
                )
            except ValueError:
                job.output.append(line)
            job.started_event.set()
            break
        job.output.append(line)
    else:
        job.started_event.set()
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
            *_build_argv(job.host, _command_script(job.host, command, cwd, marker)),
            stdin=asyncio.subprocess.PIPE if stdin is not None else asyncio.subprocess.DEVNULL,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.STDOUT,
            env=COMMAND_ENV,
            start_new_session=True,
        )
        reader = asyncio.create_task(_read_output(job, marker))
        writer = asyncio.create_task(_write_stdin(job.process, stdin))
        job.exit_code = await job.process.wait()
        await writer
        await reader
        job.status = "cancelled" if job.cancel_requested else "completed"
    except Exception as exc:
        job.status = "cancelled" if job.cancel_requested else "failed"
        job.error = str(exc)
    finally:
        job.completed_at = time.monotonic()
        job.started_event.set()
        logger.info(
            "request=%s host=%s pid=%s status=%s exit=%s duration_ms=%s",
            job.request_id,
            job.host,
            job.target_pid,
            job.status,
            job.exit_code,
            round((job.completed_at - job.started_at) * 1000),
        )


def _prune_jobs() -> None:
    now = time.monotonic()
    for request_id, job in list(jobs.items()):
        if job.completed_at is not None and now - job.completed_at >= FINISHED_TTL_SECONDS:
            jobs.pop(request_id, None)


def _payload(job: Job) -> dict[str, object]:
    output, truncated, omitted = job.output.drain()
    end = job.completed_at or time.monotonic()
    payload: dict[str, object] = {
        "status": job.status if job.completed_at is not None else "running",
        "host": job.host,
        "duration_ms": round((end - job.started_at) * 1000),
        "output": output,
        "output_truncated": truncated,
    }
    if omitted:
        payload["omitted_bytes"] = omitted
    if job.target_pid is not None:
        payload["pid"] = job.target_pid
    if job.completed_at is None:
        payload["request_id"] = job.request_id
    if job.exit_code is not None:
        payload["exit_code"] = job.exit_code
    if job.error is not None:
        payload["error"] = job.error
    return payload


async def _result(job: Job, wait_seconds: float) -> dict[str, object]:
    await job.started_event.wait()
    if job.task is not None and not job.task.done() and wait_seconds:
        try:
            await asyncio.wait_for(asyncio.shield(job.task), timeout=wait_seconds)
        except TimeoutError:
            pass

    payload = _payload(job)
    if job.completed_at is not None:
        jobs.pop(job.request_id, None)
    return payload


async def _run_quiet(host: Host, script: str) -> None:
    process = await asyncio.create_subprocess_exec(
        *_build_argv(host, script),
        stdin=asyncio.subprocess.DEVNULL,
        stdout=asyncio.subprocess.DEVNULL,
        stderr=asyncio.subprocess.DEVNULL,
        env=COMMAND_ENV,
        start_new_session=True,
    )
    await asyncio.wait_for(process.wait(), timeout=5)


async def _signal_target(job: Job, sig: str) -> None:
    if job.target_pid is None:
        return
    script = f"""
kill_tree() {{
  parent="$1"
  children=$(pgrep -P "$parent" 2>/dev/null || true)
  kill -s {sig} "$parent" 2>/dev/null || true
  for child in $children; do
    kill_tree "$child"
  done
}}
kill_tree {job.target_pid}
"""
    try:
        await _run_quiet(job.host, script)
    except Exception:
        pass


async def _capture(
    host: Host,
    script: str,
    stdin: bytes | None = None,
) -> tuple[int, bytes, str]:
    process = await asyncio.create_subprocess_exec(
        *_build_argv(host, script),
        stdin=asyncio.subprocess.PIPE if stdin is not None else asyncio.subprocess.DEVNULL,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
        env=COMMAND_ENV,
        start_new_session=True,
    )
    stdout, stderr = await process.communicate(stdin)
    return process.returncode, stdout, stderr.decode(errors="replace")


def _validate_patch_text(patch: str) -> None:
    if "\0" in patch:
        raise ValueError("patch must be text")
    if len(re.findall(r"^diff --git ", patch, flags=re.MULTILINE)) > 1:
        raise ValueError("file_patch accepts a patch for one file only")
    if "@@" not in patch:
        raise ValueError("patch must contain at least one unified diff hunk")


def _normalise_diff_headers(path: str, diff: bytes) -> bytes:
    lines = diff.splitlines(keepends=True)
    if len(lines) >= 2 and lines[0].startswith(b"--- ") and lines[1].startswith(b"+++ "):
        lines[0] = f"--- {path}\n".encode()
        lines[1] = f"+++ {path}\n".encode()
    return b"".join(lines)


@mcp.tool()
async def shell_exec(
    host: Host,
    command: str,
    cwd: str | None = None,
    wait_seconds: float = WAIT_SECONDS,
    stdin: str | None = None,
) -> dict[str, object]:
    """Run a non-interactive command. Long-running commands continue as tracked jobs."""
    _prune_jobs()
    if cwd is not None:
        cwd = _validate_absolute_path(cwd, "cwd")
    wait_seconds = _validate_wait_seconds(wait_seconds)

    if len(jobs) >= MAX_JOBS:
        finished = min(
            (job for job in jobs.values() if job.completed_at is not None),
            key=lambda job: job.completed_at or 0,
            default=None,
        )
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
    """Return new output and current state for a tracked background command."""
    _prune_jobs()
    job = jobs.get(request_id)
    if job is None:
        raise ValueError("unknown or expired request_id")
    return await _result(job, _validate_wait_seconds(wait_seconds))


@mcp.tool()
async def shell_cancel(request_id: str) -> dict[str, object]:
    """Cancel a tracked command and its target process tree."""
    _prune_jobs()
    job = jobs.get(request_id)
    if job is None:
        raise ValueError("unknown or expired request_id")
    if job.completed_at is not None:
        payload = _payload(job)
        jobs.pop(request_id, None)
        return payload

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

    payload = _payload(job)
    jobs.pop(request_id, None)
    return payload


@mcp.tool()
async def file_patch(
    host: Host,
    path: str,
    patch: str,
    expected_sha256: str | None = None,
) -> dict[str, object]:
    """Atomically apply one unified diff to one existing text file."""
    path = _validate_absolute_path(path, "path")
    _validate_patch_text(patch)
    if expected_sha256 is not None and not re.fullmatch(r"[0-9a-fA-F]{64}", expected_sha256):
        raise ValueError("expected_sha256 must be a 64-character hexadecimal SHA-256")

    target = shlex.quote(path)
    expected = shlex.quote(expected_sha256.lower()) if expected_sha256 else '""'
    meta = f"__CHATGPT_FILE_PATCH_{uuid.uuid4().hex}__"
    script = f"""
target={target}
expected={expected}
meta={shlex.quote(meta)}
if [ -L "$target" ]; then
  echo "refusing to patch a symlink" >&2
  exit 65
fi
if [ ! -f "$target" ]; then
  echo "file does not exist or is not a regular file" >&2
  exit 66
fi
size=$(wc -c < "$target" | tr -d ' ')
if [ "$size" -gt {MAX_FILE_BYTES} ]; then
  echo "file exceeds {MAX_FILE_BYTES} byte edit limit" >&2
  exit 67
fi
if [ "$size" -gt 0 ]; then
  encoding=$(file -b --mime-encoding "$target")
  case "$encoding" in
    us-ascii|utf-8) ;;
    *) echo "file_patch only supports UTF-8 text files" >&2; exit 68 ;;
  esac
fi
sha256() {{
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{{print $1}}'
  else
    shasum -a 256 "$1" | awk '{{print $1}}'
  fi
}}
dir=$(dirname "$target")
base=$(basename "$target")
old=$(mktemp "$dir/.$base.chatgpt-shell-old.XXXXXX") || exit
new=$(mktemp "$dir/.$base.chatgpt-shell-new.XXXXXX") || exit
trap 'rm -f "$old" "$new"' EXIT HUP INT TERM
rm -f "$old" "$new"
cp -p "$target" "$old" || exit
old_sha=$(sha256 "$old") || exit
if [ -n "$expected" ] && [ "$old_sha" != "$expected" ]; then
  echo "file changed since it was read" >&2
  exit 73
fi
cp -p "$old" "$new" || exit
patch -s -f -F 0 "$new" || exit
if cmp -s "$old" "$new"; then
  echo "patch produced no changes" >&2
  exit 74
fi
if [ -L "$target" ] || ! cmp -s "$old" "$target"; then
  echo "file changed while patch was being prepared" >&2
  exit 73
fi
new_sha=$(sha256 "$new") || exit
bytes=$(wc -c < "$new" | tr -d ' ')
mv -f "$new" "$target" || exit
printf '%s\\n' "$meta"
printf 'old_sha256=%s\\n' "$old_sha"
printf 'new_sha256=%s\\n' "$new_sha"
printf 'bytes_written=%s\\n' "$bytes"
printf '%s\\n' "$meta"
diff -u "$old" "$target"
rc=$?
[ "$rc" -le 1 ] || exit "$rc"
"""
    returncode, stdout, stderr = await _capture(host, script, patch.encode())
    if returncode:
        raise ValueError(stderr.strip() or f"failed to patch {path}")

    marker = f"{meta}\n".encode()
    parts = stdout.split(marker, 2)
    if len(parts) != 3:
        raise RuntimeError("file_patch did not return expected metadata")

    metadata = {}
    for line in parts[1].decode().splitlines():
        key, separator, value = line.partition("=")
        if separator:
            metadata[key] = value

    diff_output = BoundedOutput()
    diff_output.append(_normalise_diff_headers(path, parts[2]))
    diff, truncated, omitted = diff_output.drain()

    result: dict[str, object] = {
        "status": "applied",
        "host": host,
        "path": path,
        "old_sha256": metadata["old_sha256"],
        "new_sha256": metadata["new_sha256"],
        "bytes_written": int(metadata["bytes_written"]),
        "diff": diff,
        "diff_truncated": truncated,
    }
    if omitted:
        result["omitted_diff_bytes"] = omitted
    return result


if __name__ == "__main__":
    mcp.run()
