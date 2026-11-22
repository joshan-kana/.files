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
    CHATGPT_SHELL_COMMAND_PATH="/bin",
    CHATGPT_SHELL_BASH="bash",
    CHATGPT_SHELL_LOCAL_HOST="local",
    CHATGPT_SHELL_REMOTE_TARGETS="{}",
    CHATGPT_SHELL_APPROVAL_DIR="/tmp/shell-gateway-test-approvals",
    CHATGPT_SHELL_STATE_DIR="/tmp/shell-gateway-test-state",
    CHATGPT_SHELL_POLICIES_FILE="/tmp/shell-gateway-test-policies",
    CHATGPT_SHELL_WORKER="agent-workspaces",
    CHATGPT_SHELL_WORKER_ENV='{"HOME":"/var/lib/apps/agent-workspaces","HC_SESSION":"chatgpt-shell","XDG_RUNTIME_DIR":"/run/agent-workspaces","XDG_CONFIG_HOME":"/var/lib/apps/agent-workspaces/.config","XDG_STATE_HOME":"/var/lib/apps/agent-workspaces/.local/state"}',
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
            result = await shell.shell_exec("remote", "printf '%s\\n' \"$PWD\"; cat", cwd="/tmp", stdin="hello\n")
        self.assertTrue(result["success"])
        self.assertEqual(result["output"], "/tmp\nhello\n")

    async def test_nonzero_exit_is_not_success(self):
        """Report failed command exit statuses accurately."""
        result = await shell.shell_exec("remote", "exit 17")
        self.assertEqual(result["status"], "completed")
        self.assertFalse(result["success"])
        self.assertEqual(result["exit_code"], 17)

    async def test_missing_cwd_stops_execution(self):
        """Reject execution when the working directory is unavailable."""
        result = await shell.shell_exec("remote", "echo should-not-run", cwd="/not-a-real-working-directory")
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
        started = await shell.shell_exec("remote", "printf payload", wait_seconds=0)
        await shell.jobs[started["request_id"]].task
        listing = await shell.shell_jobs()
        self.assertEqual(listing[0]["request_id"], started["request_id"])
        self.assertNotIn("output", listing[0])
        self.assertEqual(listing[0]["status"], "completed")
        self.assertEqual((await shell.shell_result(started["request_id"]))["output"], "payload")

    async def test_job_recovery_and_expiration(self):
        """Recover running jobs and expire completed job records."""
        started = await shell.shell_exec("remote", "sleep 0.15; printf 'done'", wait_seconds=0)
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
        result = await shell.shell_exec("remote", "sleep 5 & echo child=$!", wait_seconds=3)
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
        started = await shell.shell_exec("remote", "sleep 5 & echo child=$!", wait_seconds=0)
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
        started = await shell.shell_exec("remote", "sleep 60; printf unsafe-continuation", wait_seconds=0)
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
        self.assertIn("--user=agent-workspaces", argv[-1])
        self.assertIn("--non-interactive", argv[-1])
        self.assertIn("SSH_AUTH_SOCK", argv[-1])
        self.assertIn("id -u; touch should-not-be-interpreted", argv[-1])

    def test_remote_command_uses_existing_ssh_without_extra_workers(self):
        """Remote commands use the configured SSH identity, without extra Herdr daemons."""
        self.argv.stop()
        try:
            with patch.dict(
                shell.REMOTE_TARGETS,
                {
                    "mac": shell.RemoteTarget("owner@mac.home", "mac-key", "/bin/zsh"),
                    "nixos-arm-parallels": shell.RemoteTarget("owner@parallels.home", "parallels-key", "/bin/bash"),
                },
            ):
                mac = shell._build_argv("mac", "id -u")
                linux = shell._build_argv("nixos-arm-parallels", "id -u")
        finally:
            self.argv.start()
        self.assertIn("-oForwardAgent=no", mac)
        self.assertIn("-oForwardAgent=no", linux)
        self.assertIn("owner@mac.home", mac)
        self.assertIn("owner@parallels.home", linux)
        self.assertIn("exec /bin/zsh -lc", mac[-1])
        self.assertIn("exec /bin/bash -lc", linux[-1])
        self.assertNotIn("agent-workspaces", " ".join(mac + linux))
        self.assertNotIn("run0", " ".join(mac + linux))
        self.assertNotIn("sudo", " ".join(mac + linux))

    def test_remote_ssh_does_not_receive_controller_elevation_credentials(self):
        """Never put the privileged agent socket in an ordinary SSH environment."""
        self.env.stop()
        try:
            with patch.dict(
                shell.REMOTE_TARGETS,
                {"nixos-arm-parallels": shell.RemoteTarget("owner@parallels", "key", "/bin/bash")},
            ):
                env = shell._command_env("nixos-arm-parallels")
                elevated = shell._command_env("nixos-arm-parallels", elevated=True)
        finally:
            self.env.start()
        self.assertNotIn("SSH_AUTH_SOCK", env)
        self.assertEqual(elevated["SSH_AUTH_SOCK"], shell.REMOTE_AUTH_AGENT)

    async def test_local_core_failure_never_falls_back_to_unobserved_shell(self):
        """Fail closed when the Core runtime is unavailable."""
        with patch.object(shell, "_herdr", new_callable=AsyncMock, side_effect=RuntimeError("Core unavailable")):
            result = await shell.shell_exec("local", "printf 'should-not-run'", wait_seconds=2)
        self.assertEqual(result["status"], "failed")
        self.assertFalse(result["success"])
        self.assertNotIn("should-not-run", result["output"])

    async def test_native_herdr_command_tracks_exit_and_output(self):
        """Observe one terminal, retaining the real nonzero exit status."""
        response = iter(
            [
                {"address": "t17", "state": "live"},
                {"ended": False, "reason": "timeout"},
                {"text": "first"},
                {"ended": True, "exit_code": 9},
                {"text": "firstsecond"},
                {"removed": "t17"},
            ]
        )

        async def native(_host, _arguments):
            return next(response)

        job = shell.Job(request_id="a" * 32, host="local")
        with patch.object(shell, "_herdr", side_effect=native) as invoke:
            await shell._run_herdr(job, "printf first; printf second; exit 9", "/tmp")
        self.assertEqual(job.exit_code, 9)
        self.assertIsNone(job.herdr_terminal)
        self.assertEqual(invoke.call_args.args[1], ["rm", "--json", "t17"])
        self.assertEqual(job.output.drain()[0], "firstsecond")
        launched = invoke.call_args_list[0].args[1]
        self.assertEqual(launched[:3], ["run", "--bg", "--json"])
        self.assertIn("origin=chatgpt-shell", launched)

    async def test_shell_exec_uses_herdr_for_no_stdin(self):
        """Route ordinary commands through native terminals without creating parallel runtimes."""

        async def mock_terminal(job, command, cwd):
            self.assertEqual(command, "printf session")
            self.assertEqual(cwd, "/tmp")
            job.herdr_terminal = "t10"
            job.exit_code = 0

        with (
            patch.object(shell, "_run_herdr", side_effect=mock_terminal) as terminal,
        ):
            result = await shell.shell_exec("local", "printf session", cwd="/tmp")
        terminal.assert_awaited_once()
        self.assertEqual(result["terminal"], "t10")
        self.assertTrue(result["success"])

    async def test_cancel_during_herdr_creation_does_not_orphan_terminal(self):
        """Interrupt the created native terminal even if cancellation arrives first."""
        creation_allowed = asyncio.Event()
        interrupted = asyncio.Event()
        calls = []

        async def fake_herdr(_host, args):
            calls.append(args)
            if args[0] == "run":
                await creation_allowed.wait()
                return {"address": "t17"}
            if args[0] == "interrupt":
                interrupted.set()
                return {"state": "finished"}
            if args[0] == "wait":
                return {"ended": True, "exit_code": 130} if interrupted.is_set() else {"ended": False, "reason": "timeout"}
            if args[0] == "read":
                return {"text": ""}
            raise AssertionError(args)

        with (
            patch.object(shell, "_herdr", side_effect=fake_herdr),
        ):
            started = await shell.shell_exec("local", "sleep 60", wait_seconds=0)
            job = shell.jobs[started["request_id"]]
            for _ in range(100):
                if job.herdr_starting:
                    break
                await asyncio.sleep(0.01)
            self.assertTrue(job.herdr_starting)
            cancellation = asyncio.create_task(shell.shell_cancel(started["request_id"]))
            await asyncio.sleep(0.02)
            creation_allowed.set()
            result = await asyncio.wait_for(cancellation, timeout=5)
        self.assertEqual(result["status"], "cancelled")
        self.assertTrue(interrupted.is_set())
        self.assertEqual(result["terminal"], "t17")
        self.assertIn(["interrupt", "--json", "t17"], calls)

    async def test_remote_shell_exec_uses_ssh_not_herdr(self):
        """Remote operations keep working even if the host has no Herdr installed."""
        with (
            patch.object(shell, "_run_herdr", new_callable=AsyncMock) as terminal,
        ):
            result = await shell.shell_exec("remote", "printf remote", wait_seconds=2)
        self.assertTrue(result["success"])
        self.assertEqual(result["output"], "remote")
        self.assertNotIn("terminal", result)
        terminal.assert_not_awaited()

    async def test_herdr_native_stdin_preserves_output_and_exit_status(self):
        """Use Core-owned execution for exact input rather than an unsandboxed worker."""
        import base64

        async def native(_host, arguments, *, stdin):
            self.assertEqual(stdin, "hello\n")
            self.assertEqual(arguments[:3], ["exec", "--json", "--stdin"])
            self.assertEqual(arguments[-3:], ["bash", "-c", "cat; exit 23"])
            return {"code": 23, "stdout": base64.b64encode(b"hello\n").decode(), "stderr": "", "truncated": False}

        with patch.object(shell, "_herdr", side_effect=native):
            result = await shell.shell_exec("local", "cat; exit 23", stdin="hello\n")
        self.assertEqual(result["exit_code"], 23)
        self.assertEqual(result["output"], "hello\n")
        self.assertFalse(result["success"])

    async def test_stdin_keeps_exact_pipe_semantics(self):
        """Keep exact input available over the existing remote SSH command path."""
        with (
            patch.object(shell, "_run_herdr", new_callable=AsyncMock) as terminal,
        ):
            result = await shell.shell_exec("remote", "cat", stdin="line\n")
        terminal.assert_not_awaited()
        self.assertEqual(result["output"], "line\n")
        self.assertTrue(result["success"])

    async def test_herdr_session_start_uses_native_runtime(self):
        """Create a native session and register the verified identity privately."""
        session_name = None

        async def native(_host, arguments):
            nonlocal session_name
            if arguments[0] == "run":
                session_name = arguments[arguments.index("--name") + 1]
                return {"address": "t8", "state": "live"}
            self.assertEqual(arguments, ["get", "--json", "t8"])
            return {"address": "t8", "name": session_name, "created_ms": 100}

        with (
            patch.object(shell, "_herdr", side_effect=native) as invoke,
            patch.object(shell.authorization, "register_terminal") as register,
        ):
            result = await shell.session_start("local", "printf test", cwd="/tmp")
        self.assertEqual(result["address"], "t8")
        self.assertEqual(result["session"], shell.HERDR_SESSION)
        args = invoke.call_args_list[0].args[1]
        self.assertIn("--bg", args)
        self.assertIn("origin=chatgpt-shell", args)
        self.assertEqual(args[-3:], ["bash", "-lc", "printf test"])
        self.assertEqual(args[args.index("--cwd") + 1], "/tmp")
        register.assert_called_once_with("t8", session_name, {"address": "t8", "name": session_name, "created_ms": 100})

    async def test_herdr_registration_failure_terminates_untracked_terminal(self):
        """An invalid native terminal identity cannot leave a managed shell running."""

        async def native(_host, arguments):
            if arguments[0] == "run":
                return {"address": "t9"}
            if arguments[0] == "get":
                return {"address": "t9", "name": "not-the-created-session", "created_ms": 1}
            return {"killed": "t9"}

        with (
            patch.object(shell, "_herdr", side_effect=native) as invoke,
            patch.object(shell.authorization, "register_terminal", side_effect=ValueError("invalid identity")),
            self.assertRaisesRegex(ValueError, "invalid identity"),
        ):
            await shell.session_start("local", "sleep 30")
        self.assertEqual(invoke.call_args.args[1], ["kill", "--json", "t9"])

    async def test_remote_sessions_are_rejected_without_remote_core(self):
        """Do not manufacture remote terminal addresses for SSH-only hosts."""
        with patch.object(shell, "_herdr", new_callable=AsyncMock) as invoke:
            with self.assertRaisesRegex(ValueError, "hosted on local"):
                await shell.session_start("remote", "true")
            with self.assertRaisesRegex(ValueError, "hosted on local"):
                await shell.session_list("remote")
            invoke.assert_not_awaited()

    async def test_herdr_session_start_rejects_relative_cwd(self):
        """Reject non-absolute working directories before spawning a terminal."""
        with patch.object(shell, "_herdr", new_callable=AsyncMock) as invoke:
            with self.assertRaises(ValueError):
                await shell.session_start("local", "true", cwd="../parent")
            invoke.assert_not_awaited()

    async def test_herdr_mutations_only_target_managed_sessions(self):
        """Mutation requires controller-registered ownership, not metadata labels."""

        async def native(_host, arguments):
            if arguments[0] == "get":
                return {"address": "t1", "name": "chatgpt-test", "created_ms": 100, "labels": {}}
            return {"address": "t1"}

        with (
            patch.object(shell, "_herdr", side_effect=native) as invoke,
            patch.object(shell.authorization, "owns_terminal", return_value=True) as owns,
            patch.object(shell.authorization, "release_terminal") as released,
        ):
            await shell.session_read("local", "t1")
            invoke.assert_awaited_once_with("local", ["read", "--json", "--lines", "100", "t1"])
            invoke.reset_mock()
            await shell.session_interrupt("local", "t1")
            self.assertEqual(invoke.await_args_list[-1].args[1], ["interrupt", "--json", "t1"])
            released.assert_not_called()
            invoke.reset_mock()
            await shell.session_kill("local", "t1")
            self.assertEqual(invoke.await_args_list[-1].args[1], ["kill", "--json", "t1"])
            released.assert_called_once_with("t1")
        self.assertEqual(owns.call_count, 4)
        self.assertEqual(shell.authorization.authorize.await_count, 2)
        self.assertEqual(shell.authorization.authorize.call_args.kwargs["session"], "chatgpt-test")

    async def test_herdr_mutations_reject_other_terminals(self):
        """A forged ChatGPT name and origin label do not confer controller ownership."""
        spoof = {"address": "t2", "name": "chatgpt-forged", "created_ms": 200, "labels": {"origin": "chatgpt-shell"}}
        with (
            patch.object(shell, "_herdr", new_callable=AsyncMock, return_value=spoof) as invoke,
            patch.object(shell.authorization, "owns_terminal", return_value=False),
            self.assertRaisesRegex(PermissionError, "not an agent-managed"),
        ):
            await shell.session_kill("local", "t2")
        invoke.assert_awaited_once_with("local", ["get", "--json", "t2"])
        shell.authorization.authorize.assert_not_awaited()

    async def test_terminal_replacement_during_approval_is_denied(self):
        """Mutation rechecks identity after an asynchronous approval delay."""

        async def native(_host, arguments):
            return {"address": "t1", "name": "chatgpt-test", "created_ms": 100}

        with (
            patch.object(shell, "_herdr", side_effect=native) as invoke,
            patch.object(shell.authorization, "owns_terminal", side_effect=[True, False]),
            self.assertRaisesRegex(PermissionError, "identity changed"),
        ):
            await shell.session_kill("local", "t1")
        self.assertEqual(invoke.await_count, 2)
        shell.authorization.authorize.assert_awaited_once()

    async def test_herdr_mutations_respect_denied_approvals(self):
        """A strict host policy requires actual approval for all terminal mutations."""

        async def native(_host, arguments):
            return {"name": "chatgpt-test", "labels": {"origin": "chatgpt-shell"}}

        with (
            patch.object(shell.authorization, "authorize", new_callable=AsyncMock, side_effect=PermissionError("not approved")),
            patch.object(shell.authorization, "owns_terminal", return_value=True),
            patch.object(shell, "_herdr", side_effect=native) as invoke,
        ):
            with self.assertRaises(PermissionError):
                await shell.session_interrupt("local", "t1")
            with self.assertRaises(PermissionError):
                await shell.session_kill("local", "t1")
            with self.assertRaises(PermissionError):
                await shell.session_start("local", "true")
            self.assertEqual(len(invoke.await_args_list), 2)

    async def test_herdr_read_bounds_scrollback(self):
        """Bound requested scrollback so a tool cannot request an unlimited response."""
        with patch.object(shell, "_herdr", new_callable=AsyncMock) as invoke:
            with self.assertRaises(ValueError):
                await shell.session_read("local", "t1", lines=100000)
            invoke.assert_not_awaited()

    def test_herdr_runs_only_on_server_worker(self):
        """Herdr CLI is never launched over the pre-existing remote SSH accounts."""
        self.argv.stop()
        try:
            local = shell._herdr_argv("local", ["ls", "--json"])
            with (
                patch.dict(shell.REMOTE_TARGETS, {"mac": shell.RemoteTarget("owner@mac", "key", "/bin/zsh")}),
                self.assertRaisesRegex(ValueError, "hosted on local"),
            ):
                shell._herdr_argv("mac", ["ls", "--json"])
        finally:
            self.argv.start()
        self.assertIn("unset SSH_AUTH_SOCK GH_TOKEN", local[-1])
        self.assertIn("--user=agent-workspaces", local[-1])

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
