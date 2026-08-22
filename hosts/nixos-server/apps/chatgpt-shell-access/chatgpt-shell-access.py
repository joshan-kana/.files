import asyncio
import os
import shlex
import uuid
from typing import Any, Literal

from mcp.server import MCPServer

MAX_OUTPUT_BYTES = 512 * 1024
MAX_JOBS = 64
WAIT_SECONDS = 10

Host = Literal["nixos-server", "mac"]

MAC_TARGET = os.environ["CHATGPT_SHELL_MAC_SSH_TARGET"]
MAC_KEY = f'{os.environ["CREDENTIALS_DIRECTORY"]}/chatgpt-shell-mac'
COMMAND_ENV = os.environ.copy()
for key in (
    "CREDENTIALS_DIRECTORY",
    "CONTROL_PLANE_API_KEY",
    "CONTROL_PLANE_TUNNEL_ID",
    "OPENAI_API_KEY",
):
    COMMAND_ENV.pop(key, None)

mcp = MCPServer("chatgpt-shell")
jobs: dict[str, asyncio.Task[dict[str, Any]]] = {}


async def _run(host: Host, command: str) -> dict[str, Any]:
    argv = (
        ["bash", "-lc", command]
        if host == "nixos-server"
        else [
            "ssh",
            "-oBatchMode=yes",
            "-oConnectTimeout=5",
            "-oIdentitiesOnly=yes",
            "-oStrictHostKeyChecking=yes",
            "-i",
            MAC_KEY,
            MAC_TARGET,
            f"exec /bin/zsh -lc {shlex.quote(command)}",
        ]
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


def _start(host: Host, command: str) -> tuple[str, asyncio.Task[dict[str, Any]]]:
    while len(jobs) >= MAX_JOBS:
        finished = next((request_id for request_id, job in jobs.items() if job.done()), None)
        if finished is None:
            raise RuntimeError("too many active jobs")
        jobs.pop(finished)

    request_id = uuid.uuid4().hex
    job = asyncio.create_task(_run(host, command))
    jobs[request_id] = job
    return request_id, job


async def _wait(request_id: str, job: asyncio.Task[dict[str, Any]]) -> dict[str, Any]:
    if not job.done():
        try:
            await asyncio.wait_for(asyncio.shield(job), WAIT_SECONDS)
        except TimeoutError:
            return {"status": "running", "request_id": request_id}

    jobs.pop(request_id, None)
    return job.result()


@mcp.tool()
async def shell_exec(host: Host, command: str) -> dict[str, Any]:
    """Run a command; long-running commands continue in the background."""
    request_id, job = _start(host, command)
    return await _wait(request_id, job)


@mcp.tool()
async def shell_result(request_id: str) -> dict[str, Any]:
    """Retrieve a background command started by shell_exec."""
    job = jobs.get(request_id)
    if job is None:
        raise ValueError("unknown or expired request_id")
    return await _wait(request_id, job)


if __name__ == "__main__":
    mcp.run()
