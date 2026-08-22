import asyncio
import os
import shlex
import uuid
from typing import Literal

from mcp.server import MCPServer

MAX_OUTPUT_BYTES = 512 * 1024
MAX_JOBS = 64
WAIT_SECONDS = 10
Host = Literal["nixos-server", "mac"]

CREDENTIALS = os.environ["CREDENTIALS_DIRECTORY"]
LOCAL = [
    "/run/wrappers/bin/sudo",
    "-n",
    "-E",
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
COMMAND_ENV = os.environ.copy()
for key in ("CREDENTIALS_DIRECTORY", "CONTROL_PLANE_API_KEY", "CONTROL_PLANE_TUNNEL_ID", "OPENAI_API_KEY"):
    COMMAND_ENV.pop(key, None)

mcp = MCPServer("chatgpt-shell")
jobs: dict[str, asyncio.Task[dict[str, object]]] = {}


async def _run(host: Host, command: str) -> dict[str, object]:
    argv = (
        [*LOCAL, f'cd -- "$HOME" || exit\n{command}']
        if host == "nixos-server"
        else [*SSH, f"exec /bin/zsh -lc {shlex.quote(command)}"]
    )
    try:
        process = await asyncio.create_subprocess_exec(
            *argv,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.STDOUT,
            env=COMMAND_ENV,
        )
        output = bytearray()
        truncated = False
        while chunk := await process.stdout.read(64 * 1024):
            remaining = MAX_OUTPUT_BYTES - len(output)
            output.extend(chunk[:remaining])
            truncated |= len(chunk) > remaining
        return {
            "status": "completed",
            "exit_code": await process.wait(),
            "output": output.decode(errors="replace"),
            "output_truncated": truncated,
        }
    except Exception as exc:
        return {"status": "failed", "error": str(exc)}


async def _result(request_id: str) -> dict[str, object]:
    job = jobs.get(request_id)
    if job is None:
        raise ValueError("unknown or expired request_id")
    if not (await asyncio.wait({job}, timeout=WAIT_SECONDS))[0]:
        return {"status": "running", "request_id": request_id}
    jobs.pop(request_id, None)
    return job.result()


@mcp.tool()
async def shell_exec(host: Host, command: str) -> dict[str, object]:
    """Run a command; long-running commands continue in the background."""
    if len(jobs) >= MAX_JOBS:
        finished = next((key for key, job in jobs.items() if job.done()), None)
        if finished is None:
            raise RuntimeError("too many active jobs")
        jobs.pop(finished)

    request_id = uuid.uuid4().hex
    jobs[request_id] = asyncio.create_task(_run(host, command))
    return await _result(request_id)


@mcp.tool()
async def shell_result(request_id: str) -> dict[str, object]:
    """Retrieve a background command started by shell_exec."""
    return await _result(request_id)


if __name__ == "__main__":
    mcp.run()
