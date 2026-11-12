"""Executable regression tests for the desktop's isolated service adapters."""

import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "scripts/linux-desktop"
THEME = ROOT / "scripts/linux-desktop/theme-set.sh"


class DesktopScriptTests(unittest.TestCase):
    """Exercise shell interfaces with private mock system services."""

    def setUp(self):
        """Allocate a private XDG state tree and mocked executable directory."""
        self.scratch = tempfile.TemporaryDirectory(prefix="desktop-scripts-")
        self.addCleanup(self.scratch.cleanup)
        self.home = Path(self.scratch.name)
        self.bin = self.home / "bin"
        self.bin.mkdir()
        self.runtime = self.home / "runtime"
        self.runtime.mkdir()
        self.state = self.home / "state"
        self.state.mkdir()
        self.env = os.environ.copy()
        self.env.update(
            {
                "HOME": str(self.home),
                "XDG_RUNTIME_DIR": str(self.runtime),
                "XDG_STATE_HOME": str(self.state),
                "XDG_CONFIG_HOME": str(self.home / "config"),
                "PATH": str(self.bin) + os.pathsep + self.env.get("PATH", ""),
                "USER": "fixture",
            }
        )

    def executable(self, name, text):
        """Write a mock command to the test-only binary search path."""
        script = self.bin / name
        script.write_text("#!/bin/sh\n" + text)
        script.chmod(0o755)
        return script

    def run_script(self, source, *arguments):
        """Execute a standalone script without touching the real user service."""
        return subprocess.run(
            ["bash", str(source), *arguments],
            env=self.env,
            text=True,
            capture_output=True,
            check=False,
            timeout=8,
        )

    def test_recording_start_acknowledges_service_owned_state(self):
        """Successful service admission is not merely a queued systemd job."""
        self.executable(
            "systemctl",
            """
if [ "$1" = --user ] && [ "$2" = start ]; then
  printf 'recording\\n42\\nrecording.mp4\\n' > "$XDG_RUNTIME_DIR/linux-desktop-recording.state"
  touch "$XDG_RUNTIME_DIR/recording-started"
  exit 0
fi
if [ "$1" = --user ] && [ "$2" = --quiet ] && [ "$3" = is-active ]; then
  test -f "$XDG_RUNTIME_DIR/recording-started"
  exit $?
fi
exit 1
""",
        )
        result = self.run_script(SCRIPTS / "recording-toggle.sh", "start", "Virtual-1", "0,0 1200x800", "none")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.runtime / "linux-desktop-recording.state").read_text().splitlines()[0], "recording")

    def test_recording_start_failure_preserves_retry_contract(self):
        """A failed start returns nonzero instead of a false successful action."""
        self.executable("systemctl", "exit 1\n")
        result = self.run_script(SCRIPTS / "recording-toggle.sh", "start", "Virtual-1", "0,0 1200x800", "none")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.runtime / "linux-desktop-recording.conf").exists())
        picker = (ROOT / "modules/desktop/hyprland/shell/qml/ScreenshotPicker.qml").read_text()
        self.assertIn("id: recordingStart", picker)
        self.assertIn("picker.open = true;", picker)
        self.assertIn("RECORDING START FAILED", picker)

    @unittest.skipUnless(shutil.which("flock"), "GNU flock is required for scope-lock integration")
    def test_theme_cancellation_prevents_scoped_build(self):
        """Cancelled work may never re-enter the build or activation phase."""
        operation = self.state / "linux-desktop/theme-operation"
        operation.mkdir(parents=True)
        (operation / "phase").write_text("cancelled\n")
        (operation / "output.log").touch()
        marker = self.home / "nh-called"
        self.executable("nh", 'printf "%s\\n" "$*" >> "$NH_MARKER"\n')
        self.env["NH_MARKER"] = str(marker)
        source = self.home / "theme.sh"
        source.write_text(
            "configuredTheme=carbon\nrepoPath=/tmp/theme\n"
            "themeFlakeRef=path:/tmp/theme\nmanifest=/tmp/unused\n"
            "expectedUser=fixture\nconfigurationName=fixture\n"
            f"operationDir={operation}\noperationUnit=linux-desktop-theme-apply.scope\n" + THEME.read_text()
        )
        source.chmod(0o700)
        self.executable("jq", "exit 0\n")
        result = self.run_script(source, "switch", "carbon", "--scoped")
        self.assertEqual(result.returncode, 130, result.stderr)
        self.assertFalse(marker.exists())
        self.assertEqual((operation / "phase").read_text().strip(), "cancelled")

    @unittest.skipUnless(shutil.which("flock"), "GNU flock is required for scope-lock integration")
    def test_theme_cancellation_after_build_blocks_activation(self):
        """A cancelled builder cannot cross the activation boundary."""
        operation = self.state / "linux-desktop/theme-operation"
        operation.mkdir(parents=True)
        (operation / "phase").write_text("preparing\n")
        (operation / "output.log").touch()
        marker = self.home / "nh-called"
        self.executable(
            "nh",
            """
printf '%s\\n' "$*" >> "$NH_MARKER"
if [ "$1" = os ] && [ "$2" = build ]; then
  printf 'cancelled\\n' > "$THEME_OPERATION_DIR/phase"
fi
""",
        )
        self.executable("jq", "exit 0\n")
        self.env.update({"NH_MARKER": str(marker), "THEME_OPERATION_DIR": str(operation)})
        source = self.home / "theme.sh"
        source.write_text(
            "configuredTheme=carbon\nrepoPath=/tmp/theme\n"
            "themeFlakeRef=path:/tmp/theme\nmanifest=/tmp/unused\n"
            "expectedUser=fixture\nconfigurationName=fixture\n"
            f"operationDir={operation}\noperationUnit=linux-desktop-theme-apply.scope\n" + THEME.read_text()
        )
        source.chmod(0o700)
        result = self.run_script(source, "switch", "carbon", "--scoped")
        self.assertEqual(result.returncode, 130, result.stderr)
        calls = marker.read_text()
        self.assertIn("os build", calls)
        self.assertNotIn("os switch", calls)
        self.assertEqual((operation / "phase").read_text().strip(), "cancelled")

    def test_browser_default_declaration_is_not_program_specific(self):
        """Bookmark navigation delegates to the XDG URL handler."""
        palette = (ROOT / "modules/desktop/hyprland/shell/qml/CommandPalette.qml").read_text()
        self.assertIn("Quickshell.execDetached([runtime.urlOpen, entry.url]);", palette)
        self.assertNotIn('["firefox", "chromium"', palette)
        indexer = (SCRIPTS / "palette-search.py").read_text()
        self.assertNotIn('home / ".config/chromium"', indexer)
        self.assertIn("XDG_CONFIG_HOME", indexer)


if __name__ == "__main__":
    unittest.main()
