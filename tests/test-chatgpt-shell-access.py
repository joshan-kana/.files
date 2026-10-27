"""Behavioral checks for the remote command execution contract."""

import asyncio
import importlib.util
import os
import signal
import sys
import time
import types
import unittest
from pathlib import Path
from unittest.mock import patch


class MCPServer:
    def __init__(self, _name):
        pass

    def tool(self):
        return lambda fn: fn


mcp = types.ModuleType("mcp")
mcp.server = types.ModuleType("mcp.server")
mcp.server.MCPServer = MCPServer
sys.modules["mcp"] = mcp
sys.modules["mcp.server"] = mcp.server

os.environ.update(
    CREDENTIALS_DIRECTORY="/tmp",
    SSH_AUTH_SOCK="/tmp/agent.sock",
    CHATGPT_SHELL_REMOTE_AUTH_AGENT="/tmp/remote-agent.sock",
    CHATGPT_SHELL_COMMAND_PATH="/bin",
    CHATGPT_SHELL_BASH="bash",
    CHATGPT_SHELL_LOCAL_HOST="local",
    CHATGPT_SHELL_REMOTE_TARGETS="{}",
)

spec = importlib.util.spec_from_file_location("shell_access", Path(sys.argv.pop(1)))
shell = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = shell
spec.loader.exec_module(shell)


class ShellTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        shell.jobs.clear()
        self.argv = patch.object(shell, "_build_argv", side_effect=lambda _host, script: ["bash", "-c", script])
        self.argv.start()
        self.env = patch.object(shell, "_command_env", side_effect=lambda _host: {**shell.COMMAND_ENV, "HOME": os.environ["HOME"]})
        self.env.start()

    def tearDown(self):
        self.env.stop()
        self.argv.stop()

    async def test_cwd_and_stdin(self):
        with patch.dict(os.environ, {"HOME": "/tmp"}):
            result = await shell.shell_exec("local", "printf '%s\\n' \"$PWD\"; cat", cwd="/tmp", stdin="hello\n")
        self.assertTrue(result["success"])
        self.assertEqual(result["output"], "/tmp\nhello\n")

    async def test_nonzero_exit_is_not_success(self):
        result = await shell.shell_exec("local", "exit 17")
        self.assertEqual(result["status"], "completed")
        self.assertFalse(result["success"])
        self.assertEqual(result["exit_code"], 17)

    async def test_missing_cwd_stops_execution(self):
        result = await shell.shell_exec("local", "echo should-not-run", cwd="/not-a-real-working-directory")
        self.assertEqual(result["exit_code"], 125)
        self.assertFalse(result["success"])
        self.assertNotIn("should-not-run", result["output"])

    async def test_startup_obeys_wait_budget(self):
        async def delayed_run(job, *_args):
            await asyncio.sleep(0.2)
            job.exit_code = 0
            job.completed_at = time.monotonic()

        with patch.object(shell, "_run", delayed_run):
            started = time.monotonic()
            result = await shell.shell_exec("local", "true", wait_seconds=0.02)
            self.assertLess(time.monotonic() - started, 0.1)
            self.assertEqual(result["status"], "running")
            self.assertFalse(result["success"])
            finished = await shell.shell_result(result["request_id"], wait_seconds=1)
            self.assertTrue(finished["success"])

    async def test_job_listing_does_not_consume_output(self):
        started = await shell.shell_exec("local", "printf payload", wait_seconds=0)
        await shell.jobs[started["request_id"]].task
        listing = await shell.shell_jobs()
        self.assertEqual(listing[0]["request_id"], started["request_id"])
        self.assertNotIn("output", listing[0])
        self.assertEqual(listing[0]["status"], "completed")
        self.assertEqual((await shell.shell_result(started["request_id"]))["output"], "payload")

    async def test_job_recovery_and_expiration(self):
        started = await shell.shell_exec("local", "sleep 0.15; printf 'done'", wait_seconds=0)
        self.assertEqual(started["status"], "running")
        self.assertIn(started["request_id"], [j["request_id"] for j in await shell.shell_jobs()])
        result = await shell.shell_result(started["request_id"], wait_seconds=1)
        self.assertTrue(result["success"])
        self.assertEqual(result["output"], "done")
        self.assertEqual((await shell.shell_result(started["request_id"]))["output"], "")
        shell.jobs[started["request_id"]].completed_at -= shell.JOB_RETENTION_SECONDS + 1
        self.assertEqual(await shell.shell_jobs(), [])

    async def test_detached_child_does_not_hold_completed_job(self):
        started = time.monotonic()
        result = await shell.shell_exec("local", "sleep 5 & echo child=$!", wait_seconds=3)
        try:
            self.assertTrue(result["success"])
            self.assertLess(time.monotonic() - started, 3)
            self.assertEqual(result["status"], "completed")
            self.assertIn("child=", result["output"])
        finally:
            if "child=" in result["output"]:
                os.kill(int(result["output"].split("child=")[1].splitlines()[0]), signal.SIGTERM)

    async def test_cancel_after_shell_exits_does_not_change_success(self):
        started = await shell.shell_exec("local", "sleep 5 & echo child=$!", wait_seconds=0)
        job = shell.jobs[started["request_id"]]

        async def wait_for_exit():
            while job.exit_code is None:
                await asyncio.sleep(0.01)

        await asyncio.wait_for(wait_for_exit(), timeout=2)
        result = await shell.shell_cancel(started["request_id"])
        try:
            self.assertEqual(result["status"], "completed")
            self.assertTrue(result["success"])
        finally:
            if "child=" in result["output"]:
                os.kill(int(result["output"].split("child=")[1].splitlines()[0]), signal.SIGTERM)

    async def test_cancel_running_tree(self):
        started = await shell.shell_exec("local", "sleep 60; printf unsafe-continuation", wait_seconds=0)
        job = shell.jobs[started["request_id"]]

        async def wait_for_pid():
            while job.target_pid is None:
                await asyncio.sleep(0.01)

        await asyncio.wait_for(wait_for_pid(), timeout=2)
        result = await shell.shell_cancel(started["request_id"])
        self.assertEqual(result["status"], "cancelled")
        self.assertFalse(result["success"])
        self.assertNotEqual(result.get("exit_code"), 0)
        self.assertNotIn("unsafe-continuation", result["output"])

    def test_home_directory_is_preserved(self):
        self.assertIn("HOME", shell._ALLOWED_ENV)
        self.assertEqual(shell.COMMAND_ENV["HOME"], os.environ["HOME"])

    def test_local_command_uses_unprivileged_shell(self):
        command = shell.LOCAL
        self.assertEqual(command[0], "bash")
        self.assertEqual(command[1], "-lc")
        self.assertNotIn("sudo", command)

    def test_remote_agent_forwarding_is_explicit(self):
        self.argv.stop()
        try:
            with patch.dict(
                shell.REMOTE_TARGETS,
                {
                    "remote": shell.RemoteTarget("joshan@example", "key", "/bin/bash", True),
                },
            ):
                argv = shell._build_argv("remote", "id -u")
        finally:
            self.argv.start()
        self.assertIn("-oForwardAgent=yes", argv)

    def test_output_buffer_bounds(self):
        output = shell.OutputBuffer()
        output.append(b"a" * shell.MAX_OUTPUT_BYTES)
        output.append(b"b" * shell.MAX_OUTPUT_BYTES)
        text, truncated, omitted = output.drain()
        self.assertTrue(truncated)
        self.assertEqual(omitted, shell.MAX_OUTPUT_BYTES)
        self.assertTrue(text.startswith("a" * shell.OUTPUT_HEAD_BYTES))
        self.assertTrue(text.endswith("b" * shell.OUTPUT_TAIL_BYTES))


if __name__ == "__main__":
    unittest.main()
