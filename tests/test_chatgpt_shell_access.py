"""Host configuration and command dispatch for the privileged shell MCP server."""

import importlib.util
import json
import os
import sys
import types
import unittest
from pathlib import Path
from typing import get_args
from unittest.mock import patch

SOURCE = Path(__file__).resolve().parents[1] / "modules/server-apps/agent-tools/chatgpt-shell-access/chatgpt-shell-access.py"


class StubMCPServer:
    def __init__(self, name):
        self.name = name

    def tool(self):
        return lambda function: function


def load_server(local_host, remote_targets):
    env = {
        "CREDENTIALS_DIRECTORY": "/run/credentials/shell",
        "SSH_AUTH_SOCK": "/run/sudo-agent.sock",
        "CHATGPT_SHELL_REMOTE_SUDO_AGENT": "/run/remote-sudo-agent.sock",
        "CHATGPT_SHELL_COMMAND_PATH": "/run/current-system/sw/bin",
        "CHATGPT_SHELL_LOCAL_USER": "operator",
        "CHATGPT_SHELL_LOCAL_HOST": local_host,
        "CHATGPT_SHELL_BASH": "/bin/bash",
        "CHATGPT_SHELL_REMOTE_TARGETS": json.dumps(remote_targets),
    }
    stub = types.ModuleType("mcp.server")
    stub.MCPServer = StubMCPServer
    spec = importlib.util.spec_from_file_location("chatgpt_shell_test_module", SOURCE)
    module = importlib.util.module_from_spec(spec)
    with (
        patch.dict(os.environ, env, clear=True),
        patch.dict(sys.modules, {"mcp": types.ModuleType("mcp"), "mcp.server": stub, spec.name: module}),
    ):
        spec.loader.exec_module(module)
    return module


def target(name, *, sudo=False):
    return {
        "ssh_target": f"operator@{name}.home",
        "credential": f"chatgpt-shell-{name}",
        "shell": "/bin/bash",
        "sudo": sudo,
    }


class ShellHostConfigurationTests(unittest.TestCase):
    def test_host_schema_tracks_remote_targets(self):
        server = load_server("server", {"workstation": target("workstation"), "vm": target("vm", sudo=True)})
        self.assertEqual(get_args(server.Host), ("server", "workstation", "vm"))
        self.assertNotIn("nixos-arm-parallels", get_args(server.Host))

        local_argv = server._build_argv("server", "echo ready")
        self.assertEqual(local_argv[:7], ["/run/wrappers/bin/sudo", "-n", "-H", "-u", "operator", "--", "/bin/bash"])
        self.assertIn("echo ready", local_argv[-1])
        self.assertNotIn("SSH_AUTH_SOCK", server._command_env("server"))

        remote_argv = server._build_argv("vm", "echo ready")
        self.assertIn("-oForwardAgent=yes", remote_argv)
        self.assertIn("/run/credentials/shell/chatgpt-shell-vm", remote_argv)
        self.assertEqual(remote_argv[-2], "operator@vm.home")
        self.assertEqual(server._command_env("vm")["SSH_AUTH_SOCK"], "/run/remote-sudo-agent.sock")

        no_sudo_argv = server._build_argv("workstation", "echo ready")
        self.assertIn("-oForwardAgent=no", no_sudo_argv)
        self.assertNotIn("SSH_AUTH_SOCK", server._command_env("workstation"))

    def test_only_local_host_is_valid_when_no_remotes_are_configured(self):
        server = load_server("server", {})
        self.assertEqual(get_args(server.Host), ("server",))
        self.assertEqual(server.REMOTE_TARGETS, {})

    def test_local_and_remote_hosts_must_be_distinct(self):
        with self.assertRaisesRegex(RuntimeError, "distinct"):
            load_server("server", {"server": target("server")})
        with self.assertRaisesRegex(RuntimeError, "nonempty"):
            load_server("", {})


if __name__ == "__main__":
    unittest.main()
