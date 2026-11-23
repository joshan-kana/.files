"""Regression tests for scoped operator authorization and replay protection."""

import asyncio
import contextlib
import importlib.util
import io
import json
import os
import sys
import tempfile
import time
import unittest
import uuid
from pathlib import Path
from unittest.mock import patch

os.environ.update(
    CHATGPT_SHELL_APPROVAL_DIR="/tmp/authorization-test-approvals",
    CHATGPT_SHELL_OPERATOR_STATE_DIR="/tmp/shell-operator-test-state",
    CHATGPT_SHELL_STATE_DIR="/tmp/authorization-test-state",
    CHATGPT_SHELL_POLICIES_FILE="/tmp/authorization-test-policies",
)

spec = importlib.util.spec_from_file_location("authorization", Path(sys.argv.pop(1)))
authorization = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = authorization
spec.loader.exec_module(authorization)


class AuthorizationTests(unittest.IsolatedAsyncioTestCase):
    """Exercise real private approval records without a running server."""

    def setUp(self):
        """Create a disposable protected authorization workspace."""
        self.scratch = tempfile.TemporaryDirectory()
        self.root = Path(self.scratch.name)
        defaults = self.root / "defaults.json"
        defaults.write_text(json.dumps({"server": {"commands": "automatic", "elevation": "ask"}}))
        self.paths = patch.multiple(
            authorization,
            DEFAULTS_FILE=defaults,
            STATE_DIR=self.root / "state",
            OPERATOR_STATE_DIR=self.root / "operator-state",
            POLICY_FILE=self.root / "operator-state" / "policies.json",
            APPROVAL_DIR=self.root / "pending",
            APPROVAL_TIMEOUT=0.5,
        )
        self.paths.start()
        self.operator = patch.object(authorization.os, "geteuid", return_value=0)
        self.operator.start()

    def tearDown(self):
        """Dispose of approval records and policy state."""
        self.operator.stop()
        self.paths.stop()
        self.scratch.cleanup()

    def ident(self):
        """Generate a valid one-time operation ID."""
        return uuid.uuid4().hex

    async def await_pending(self, ident):
        """Wait for the real operation to appear."""
        path = authorization.APPROVAL_DIR / "pending" / f"{ident}.json"
        for _ in range(50):
            if path.exists():
                return path
            await asyncio.sleep(0.01)
        self.fail("approval request did not appear")
        return None

    async def test_automatic_and_deny(self):
        """Normal commands can run without grants; denied operations never proceed."""
        await authorization.authorize(self.ident(), "server", "commands", "true", None)
        authorization._set_policy("server", "elevation", "deny", None)
        with self.assertRaises(PermissionError):
            await authorization.authorize(self.ident(), "server", "elevation", "true", None)

    async def test_human_approval_single_use(self):
        """A matching approval authorizes one exact operation and is consumed."""
        ident = self.ident()
        operation = asyncio.create_task(authorization.authorize(ident, "server", "elevation", "id -u", "/tmp"))
        await self.await_pending(ident)
        authorization._decide(ident, "approve")
        await operation
        # The gateway may read an operator decision, but must not unlink it.
        self.assertTrue((authorization.APPROVAL_DIR / "decisions" / f"{ident}.json").exists())
        self.assertFalse((authorization.APPROVAL_DIR / "pending" / f"{ident}.json").exists())
        with self.assertRaises(FileNotFoundError):
            authorization._decide(ident, "approve")

    async def test_approval_is_bound_to_stdin_and_displays_exact_text(self):
        """Bind submitted standard input and escape untrusted terminal control sequences."""
        ident = self.ident()
        payload = "first\n\x1b[2Jsecond"
        operation = asyncio.create_task(
            authorization.authorize(ident, "server", "elevation", "cat", "/tmp\nforged", payload, target_identity="root")
        )
        pending = await self.await_pending(ident)
        request = json.loads(pending.read_text())
        self.assertEqual(request["stdin"], payload)
        self.assertEqual(request["target_identity"], "root")
        modified = {key: value for key, value in request.items() if key != "digest"}
        modified["target_identity"] = "another-user"
        self.assertNotEqual(authorization._digest(modified), request["digest"])
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            authorization._list()
        self.assertNotIn("\x1b", output.getvalue())
        self.assertIn(r"\u001b", output.getvalue())
        self.assertIn(r"\nforged", output.getvalue())
        self.assertIn(r"first\n", output.getvalue())
        self.assertIn('target: "root"', output.getvalue())
        self.assertIn("expires:", output.getvalue())
        self.assertIn("scope: one operation", output.getvalue())
        authorization._decide(ident, "approve")
        await operation

    async def test_unreviewably_large_stdin_is_rejected(self):
        """Never approve a truncated view of a submitted input stream."""
        with self.assertRaisesRegex(PermissionError, "stdin exceeds"):
            await authorization.authorize(
                self.ident(), "server", "elevation", "cat", None, "x" * (authorization.MAX_REVIEW_STDIN_BYTES + 1)
            )
        self.assertFalse((authorization.APPROVAL_DIR / "pending").exists())

    async def test_human_denial_and_timeout(self):
        """Denials and unanswered requests fail closed."""
        ident = self.ident()
        operation = asyncio.create_task(authorization.authorize(ident, "server", "elevation", "true", None))
        await self.await_pending(ident)
        authorization._decide(ident, "deny")
        with self.assertRaises(PermissionError):
            await operation
        with self.assertRaisesRegex(PermissionError, "timed out"):
            await authorization.authorize(self.ident(), "server", "elevation", "true", None)

    async def test_wrong_digest_rejected(self):
        """A forged approval against another operation is not accepted."""
        ident = self.ident()
        operation = asyncio.create_task(authorization.authorize(ident, "server", "elevation", "true", None))
        await self.await_pending(ident)
        authorization._write_exclusive(
            authorization.APPROVAL_DIR / "decisions" / f"{ident}.json",
            {"decision": "approve", "digest": "0" * 64},
        )
        with self.assertRaisesRegex(PermissionError, "does not match"):
            await operation

    async def test_policy_revocation_during_approval(self):
        """Changing a host policy to deny revokes a previously submitted approval."""
        ident = self.ident()
        operation = asyncio.create_task(authorization.authorize(ident, "server", "elevation", "true", None))
        await self.await_pending(ident)
        authorization._decide(ident, "approve")
        authorization._set_policy("server", "elevation", "deny", None)
        with self.assertRaisesRegex(PermissionError, "changed to deny"):
            await operation

    async def test_policy_revision_invalidates_pending_approval(self):
        """Rewriting an ask policy invalidates approvals submitted before the change."""
        ident = self.ident()
        operation = asyncio.create_task(authorization.authorize(ident, "server", "elevation", "true", None))
        await self.await_pending(ident)
        authorization._set_policy("server", "elevation", "ask", None)
        authorization._decide(ident, "approve")
        with self.assertRaisesRegex(PermissionError, "policy changed"):
            await operation

    async def test_unrelated_policy_does_not_invalidate_pending_approval(self):
        """An unrelated command-policy change does not revoke an elevation review."""
        ident = self.ident()
        operation = asyncio.create_task(authorization.authorize(ident, "server", "elevation", "true", None))
        await self.await_pending(ident)
        authorization._set_policy("server", "commands", "ask", None)
        authorization._decide(ident, "approve")
        await operation

    async def test_bounded_elevation_policy(self):
        """Automatic elevation requires an expiry and falls back to the safe default."""
        with self.assertRaises(ValueError):
            authorization._set_policy("server", "elevation", "automatic", None)
        with self.assertRaises(ValueError):
            authorization._set_policy("server", "elevation", "automatic", 3601)
        authorization._set_policy("server", "elevation", "automatic", 1)
        self.assertEqual(authorization.effective("server", "elevation"), "automatic")
        with patch.object(authorization.time, "time", return_value=time.time() + 2):
            self.assertEqual(authorization.effective("server", "elevation"), "ask")

    def test_declarative_deny_is_a_permission_ceiling(self):
        """Saved runtime grants may not override an administrator's explicit deny."""
        defaults = authorization.DEFAULTS_FILE
        defaults.write_text(json.dumps({"server": {"commands": "deny", "elevation": "ask"}}))
        authorization._write_atomic(
            authorization.POLICY_FILE,
            {"server": {"commands": {"mode": "automatic", "expires_at": time.time() + 60}}},
        )
        self.assertEqual(authorization.effective("server", "commands"), "deny")
        with self.assertRaises(PermissionError):
            authorization._set_policy("server", "commands", "automatic", 60)

    def test_session_specific_grant_is_bounded(self):
        """A strict session does not restrict other sessions or grant indefinite access."""
        authorization._set_policy("server", "commands", "ask", None, session="chatgpt-a")
        self.assertEqual(authorization.effective("server", "commands", "chatgpt-a"), "ask")
        self.assertEqual(authorization.effective("server", "commands", "chatgpt-b"), "automatic")
        with self.assertRaisesRegex(ValueError, "require a TTL"):
            authorization._set_policy("server", "commands", "automatic", None, session="chatgpt-a")
        authorization._set_policy("server", "commands", "automatic", 1, session="chatgpt-a")
        self.assertEqual(authorization.effective("server", "commands", "chatgpt-a"), "automatic")
        with patch.object(authorization.time, "time", return_value=time.time() + 2):
            self.assertEqual(authorization.effective("server", "commands", "chatgpt-a"), "automatic")
        with self.assertRaises(ValueError):
            authorization._set_policy("server", "commands", "ask", None, session="../../other")

    async def test_approval_is_bound_to_session_identity(self):
        """One approval cannot be replayed against another terminal's control action."""
        authorization._set_policy("server", "commands", "ask", None, session="chatgpt-a")
        ident = self.ident()
        operation = asyncio.create_task(authorization.authorize(ident, "server", "commands", "hc interrupt t1", None, session="chatgpt-a"))
        pending = await self.await_pending(ident)
        request = json.loads(pending.read_text())
        self.assertEqual(request["session"], "chatgpt-a")
        changed = {key: value for key, value in request.items() if key != "digest"}
        changed["session"] = "chatgpt-b"
        self.assertNotEqual(authorization._digest(changed), request["digest"])
        authorization._decide(ident, "approve")
        await operation

    def test_controller_registry_rejects_forged_terminal_metadata(self):
        """Client labels and names cannot create controller-owned authority."""
        metadata = {
            "address": "t8",
            "name": "chatgpt-owned",
            "created_ms": 100,
            "labels": {"origin": "chatgpt-shell"},
        }
        self.assertFalse(authorization.owns_terminal("t8", metadata))
        authorization.register_terminal("t8", "chatgpt-owned", metadata)
        record = authorization.STATE_DIR / "managed-terminals.json"
        self.assertEqual(record.stat().st_mode & 0o777, 0o600)
        self.assertTrue(authorization.owns_terminal("t8", metadata))
        self.assertFalse(authorization.owns_terminal("t8", {**metadata, "created_ms": 101}))
        self.assertFalse(authorization.owns_terminal("t8", {**metadata, "address": "t9"}))
        self.assertFalse(authorization.owns_terminal("t9", {**metadata, "address": "t9"}))
        with self.assertRaises(ValueError):
            authorization.register_terminal("t8", "chatgpt-owned", metadata)
        authorization.release_terminal("t8")
        self.assertFalse(authorization.owns_terminal("t8", metadata))

    def test_untrusted_remote_user_cannot_approve_or_edit_policy(self):
        """The SSH account alone must not be an operator identity."""
        with patch.object(authorization.os, "geteuid", return_value=1000):
            with self.assertRaisesRegex(PermissionError, "require run0"):
                authorization._decide(self.ident(), "approve")
            with self.assertRaisesRegex(PermissionError, "require run0"):
                authorization._set_policy("server", "commands", "deny", None)

    def test_policy_file_is_group_readable_but_not_group_writable(self):
        """The gateway can consume a root-written policy without changing it."""
        authorization._set_policy("server", "commands", "ask", None)
        self.assertEqual(authorization.POLICY_FILE.stat().st_mode & 0o777, 0o640)
        self.assertEqual(authorization.effective("server", "commands"), "ask")

    def test_unknown_host_and_bad_ids(self):
        """Unknown hosts and invalid identifiers never map into a filesystem request."""
        with self.assertRaises(ValueError):
            authorization.effective("attacker", "commands")
        with self.assertRaises(ValueError):
            authorization._valid_id("../../other")


if __name__ == "__main__":
    unittest.main()
