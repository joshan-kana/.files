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
from unittest.mock import AsyncMock, patch


class MCPServer:
    """Stand in for MCP tool registration during tests."""

    def __init__(self, _name):
        """Initialize the mock registration server."""

    def tool(self):
        """Return a decorator that registers tool functions for testing."""
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
    CHATGPT_SHELL_LOCAL_WORKER='{"ssh_target":"worker@127.0.0.1","credential":"worker-key","shell":"/bin/bash","forwardAgent":false}',
    CHATGPT_SHELL_COMMAND_PATH="/bin",
    CHATGPT_SHELL_BASH="bash",
    CHATGPT_SHELL_LOCAL_HOST="local",
    CHATGPT_SHELL_REMOTE_TARGETS="{}",
)

shell_path = Path(sys.argv.pop(1)).resolve()
sys.path.insert(0, str(shell_path.parent))
spec = importlib.util.spec_from_file_location("shell_access", shell_path)
shell = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = shell
spec.loader.exec_module(shell)


class ShellTests(unittest.IsolatedAsyncioTestCase):
    """Test bounded and authorized shell execution behavior."""

    def setUp(self):
        """Prepare an isolated shell server for each test."""
        shell.jobs.clear()
        self.argv = patch.object(shell, "_build_argv", side_effect=lambda _host, script: ["bash", "-c", script])
        self.argv.start()
        self.env = patch.object(
            shell, "_command_env", side_effect=lambda _host, **_kwargs: {**shell.COMMAND_ENV, "HOME": os.environ["HOME"]}
        )
        self.env.start()
        self.auth = patch.object(shell.authorization, "authorize", new_callable=AsyncMock)
        self.auth.start()
        self.effective = patch.object(shell.authorization, "effective", return_value="automatic")
        self.effective.start()

    def tearDown(self):
        """Restore patched process and server state after each test."""
        self.effective.stop()
        self.auth.stop()
        self.env.stop()
        self.argv.stop()

    async def test_cwd_and_stdin(self):
        """Pass the requested working directory and standard input."""
        with patch.dict(os.environ, {"HOME": "/tmp"}):
            result = await shell.shell_exec("local", "printf '%s\\n' \"$PWD\"; cat", cwd="/tmp", stdin="hello\n")
        self.assertTrue(result["success"])
        self.assertEqual(result["output"], "/tmp\nhello\n")

    async def test_nonzero_exit_is_not_success(self):
        """Report failed command exit statuses accurately."""
        result = await shell.shell_exec("local", "exit 17")
        self.assertEqual(result["status"], "completed")
        self.assertFalse(result["success"])
        self.assertEqual(result["exit_code"], 17)

    async def test_missing_cwd_stops_execution(self):
        """Reject execution when the working directory is unavailable."""
        result = await shell.shell_exec("local", "echo should-not-run", cwd="/not-a-real-working-directory")
        self.assertEqual(result["exit_code"], 125)
        self.assertFalse(result["success"])
        self.assertNotIn("should-not-run", result["output"])

    async def test_startup_obeys_wait_budget(self):
        """Honor startup wait budgets without losing running jobs."""

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
        """List jobs without draining their buffered output."""
        started = await shell.shell_exec("local", "printf payload", wait_seconds=0)
        await shell.jobs[started["request_id"]].task
        listing = await shell.shell_jobs()
        self.assertEqual(listing[0]["request_id"], started["request_id"])
        self.assertNotIn("output", listing[0])
        self.assertEqual(listing[0]["status"], "completed")
        self.assertEqual((await shell.shell_result(started["request_id"]))["output"], "payload")

    async def test_job_recovery_and_expiration(self):
        """Recover running jobs and expire completed job records."""
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
        """Finish a job even when detached children retain output pipes."""
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
        """Keep completed results intact after a late cancellation request."""
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
        """Cancel the running process tree rather than its leader alone."""
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
        """Retain the configured home directory for shell commands."""
        self.assertIn("HOME", shell._ALLOWED_ENV)
        self.assertEqual(shell.COMMAND_ENV["HOME"], os.environ["HOME"])

    def test_local_command_uses_run0_worker_boundary(self):
        """Interpret ordinary scripts only after entering the restricted identity."""
        self.argv.stop()
        try:
            argv = shell._build_argv("local", "id -u; touch should-not-be-interpreted")
        finally:
            self.argv.start()
        self.assertEqual(argv[:2], ["bash", "-lc"])
        self.assertIn("--user=herdr-worker", argv[-1])
        self.assertIn("--non-interactive", argv[-1])
        self.assertIn("SSH_AUTH_SOCK", argv[-1])
        self.assertIn("id -u; touch should-not-be-interpreted", argv[-1])

    def test_remote_command_changes_identity_before_agent_shell(self):
        """Use native remote execution without exposing the primary user's shell."""
        self.argv.stop()
        try:
            with patch.dict(
                shell.REMOTE_TARGETS,
                {
                    "mac": shell.RemoteTarget("owner@mac.home", "mac-key", "/bin/zsh", False),
                    "nixos-arm-parallels": shell.RemoteTarget("owner@parallels.home", "parallels-key", "/bin/bash", True),
                },
            ):
                mac = shell._build_argv("mac", "id -u")
                linux = shell._build_argv("nixos-arm-parallels", "id -u")
        finally:
            self.argv.start()
        self.assertIn("-oForwardAgent=no", mac)
        self.assertIn("owner@mac.home", mac)
        self.assertIn("sudo -n -H -u herdr-worker", mac[-1])
        self.assertIn("-oForwardAgent=yes", linux)
        self.assertIn("owner@parallels.home", linux)
        self.assertIn("--user=herdr-worker", linux[-1])

    async def test_herdr_session_start_uses_native_runtime(self):
        """Create a labelled session without writing a competing terminal database."""
        with patch.object(shell, "_herdr", new_callable=AsyncMock, return_value={"address": "t8", "state": "live"}) as invoke:
            result = await shell.session_start("local", "printf test", cwd="/tmp")
        self.assertEqual(result["address"], "t8")
        self.assertEqual(result["session"], shell.HERDR_SESSION)
        args = invoke.call_args.args[1]
        self.assertIn("--bg", args)
        self.assertIn("origin=chatgpt-shell", args)
        self.assertEqual(args[-3:], ["bash", "-lc", "printf test"])
        self.assertEqual(args[args.index("--cwd") + 1], "/tmp")

    async def test_herdr_session_start_rejects_relative_cwd(self):
        """Reject non-absolute working directories before spawning a terminal."""
        with patch.object(shell, "_herdr", new_callable=AsyncMock) as invoke:
            with self.assertRaises(ValueError):
                await shell.session_start("local", "true", cwd="../parent")
            invoke.assert_not_awaited()

    async def test_herdr_interrupt_is_limited_to_managed_sessions(self):
        """Never interrupt an unrelated Herdr terminal through the MCP tool."""
        with patch.object(shell, "_herdr", new_callable=AsyncMock) as invoke:
            invoke.return_value = {"terminals": []}
            with self.assertRaises(ValueError):
                await shell.session_interrupt("local", "t1")
            invoke.assert_awaited_once()
            self.assertIn("origin=chatgpt-shell", invoke.call_args.args[1])

    async def test_herdr_read_bounds_scrollback(self):
        """Bound requested scrollback so a tool cannot request an unlimited response."""
        with patch.object(shell, "_herdr", new_callable=AsyncMock) as invoke:
            with self.assertRaises(ValueError):
                await shell.session_read("local", "t1", lines=100000)
            invoke.assert_not_awaited()

    def test_herdr_runs_under_the_same_restricted_identity(self):
        """Invoke the native terminal runtime only through the worker launcher."""
        self.argv.stop()
        try:
            local = shell._herdr_argv("local", ["ls", "--json"])
            with patch.dict(shell.REMOTE_TARGETS, {"mac": shell.RemoteTarget("owner@mac", "key", "/bin/zsh", False)}):
                remote = shell._herdr_argv("mac", ["ls", "--json"])
        finally:
            self.argv.start()
        self.assertIn("unset SSH_AUTH_SOCK GH_TOKEN", local[-1])
        self.assertIn("--user=herdr-worker", local[-1])
        self.assertIn("-oForwardAgent=no", remote)
        self.assertIn("sudo -n -H -u herdr-worker", remote[-1])

    def test_output_buffer_bounds(self):
        """Cap retained output without dropping the final result."""
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
