"""Executable regression tests for the desktop's isolated service adapters."""

import os
import datetime as dt
import importlib.util
import json
import sys
from unittest import mock
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "scripts/desktop-shell"
THEME = ROOT / "scripts/desktop-shell/theme-set.sh"


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

    def theme_runner(self, operation):
        """Wrap the real theme script with strict shell settings and mock inputs."""
        source = self.home / "theme.sh"
        source.write_text(
            "set -euo pipefail\n"
            "configuredTheme=carbon\nrepoPath=/tmp/theme\n"
            "themeFlakeRef=path:/tmp/theme\nmanifest=/tmp/unused\n"
            "expectedUser=fixture\nconfigurationName=fixture\n"
            f"operationDir={operation}\noperationUnit=desktop-shell-theme-apply.service\n" + THEME.read_text()
        )
        source.chmod(0o700)
        return source

    def test_night_light_schedule_and_migration(self):
        """Night Light inherits defaults, honours overnight days and temporary overrides."""
        spec = importlib.util.spec_from_file_location("night_light", SCRIPTS / "night-light.py")
        night = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(night)
        config = dict(night.DEFAULTS, mode="custom", days=2, temperature=4300, transitionMinutes=15)
        monday = dt.datetime(2026, 11, 23, 19, 0, tzinfo=dt.timezone.utc)
        self.assertEqual(night.effective(monday, config, {})[0], 6500)
        self.assertEqual(night.effective(monday + dt.timedelta(minutes=15), config, {})[0], 4300)
        tuesday = monday + dt.timedelta(hours=10)
        self.assertEqual(night.effective(tuesday, config, {})[0], 4300)
        self.assertEqual(night.effective(tuesday + dt.timedelta(hours=2), config, {})[0], 6500)
        self.assertEqual(night.effective(monday + dt.timedelta(days=1, minutes=30), config, {})[0], 6500)
        pause = {"override": "off", "until": tuesday.timestamp() + 60}
        self.assertEqual(night.effective(tuesday, config, pause)[0], 6500)
        self.assertEqual(night.effective(tuesday + dt.timedelta(seconds=61), config, pause)[0], 4300)
        self.assertFalse(night.solar_available(config))
        self.assertTrue(night.solar_available(dict(config, latitude=-31.95, longitude=115.86)))
        state = self.state / "night-light"
        state.write_text("off 4300\n")
        with mock.patch.object(night, "STATE", state):
            self.assertEqual(night.read_overrides(monday), {"mode": "off", "temperature": 4300})
            state.write_text(json.dumps({"mode": "custom", "temperature": 9999, "days": 62}))
            self.assertEqual(night.read_overrides(monday), {"mode": "custom", "days": 62})

    def test_night_light_service_controls(self):
        """Check real adapter transitions through an isolated mock systemd/Hyprland."""
        self.executable("systemctl", """
case "$*" in
  *"is-active desktop-shell-night-light.service") test -f "$XDG_RUNTIME_DIR/light-running";;
  *"start desktop-shell-night-light.service") touch "$XDG_RUNTIME_DIR/light-running";;
  *"stop desktop-shell-night-light.service") rm -f "$XDG_RUNTIME_DIR/light-running";;
  *) exit 0;;
esac
""")
        self.executable("hyprctl", 'printf "%s\\n" "$*" > "$XDG_RUNTIME_DIR/light-command"; echo ok')
        def run(*args):
            result = subprocess.run([sys.executable, str(SCRIPTS / "night-light.py"), *args], env=self.env,
                                    text=True, capture_output=True, check=True, timeout=8)
            return result.stdout
        run("mode", "manual")
        self.assertTrue(json.loads(run("state"))["active"])
        run("set", "4100")
        self.assertEqual(json.loads(run("state"))["effectiveTemperature"], 4100)
        self.assertEqual((self.runtime / "light-command").read_text().strip(), "hyprsunset temperature 4100")
        run("pause", "30")
        self.assertFalse(json.loads(run("state"))["active"])
        run("toggle")
        self.assertTrue(json.loads(run("state"))["active"])
        run("reset")
        self.assertFalse(json.loads(run("state"))["active"])
        self.assertEqual(json.loads(run("state"))["temperature"], 4500)

    def test_video_wallpaper_keeps_diagnostics_without_terminal_progress(self):
        """Both video launch paths retain diagnostics without terminal status output."""
        output = "Sample-Output"
        video = self.home / "wallpaper.mp4"
        video.write_bytes(b"fixture")
        wallpapers = self.state / "desktop-shell" / "wallpapers"
        wallpapers.mkdir(parents=True)
        self.executable("mpvpaper", 'printf "%s\\n" "$@" > "$XDG_RUNTIME_DIR/mpvpaper-args"')
        self.executable("awww", f"echo ': {output}: 100x100'")

        for target, resize in ((output, "crop"), ("all", "fit")):
            (wallpapers / f"{target}.wall").write_text(f"{resize}\n{video}\n")
            result = self.run_script(SCRIPTS / "wallpaper-video-from-state.sh", target)
            arguments = (self.runtime / "mpvpaper-args").read_text().splitlines()
            self.assertIn("-o", arguments, result.stderr)
            options = arguments[arguments.index("-o") + 1].split()
            self.assertTrue({"quiet=yes", "input-terminal=no", "no-audio", "loop-file=inf", "hwdec=auto"}.issubset(options))
            self.assertEqual("panscan=1" in options, resize == "crop")
            self.assertEqual(arguments[-2:], [output, str(video)])
            if target != "all":
                (wallpapers / f"{target}.wall").unlink()

    def test_recording_start_acknowledges_service_owned_state(self):
        """Successful service admission is not merely a queued systemd job."""
        self.executable(
            "systemctl",
            """
if [ "$1" = --user ] && [ "$2" = start ]; then
  printf "video-frame" > "$XDG_RUNTIME_DIR/recording.mp4"
  printf 'recording\n42\n%s/recording.mp4\n' "$XDG_RUNTIME_DIR" > "$XDG_RUNTIME_DIR/desktop-shell-recording.state"
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
        self.assertEqual((self.runtime / "desktop-shell-recording.state").read_text().splitlines()[0], "recording")

    def test_recording_start_failure_preserves_retry_contract(self):
        """A failed start returns nonzero instead of a false successful action."""
        self.executable("systemctl", "exit 1\n")
        result = self.run_script(SCRIPTS / "recording-toggle.sh", "start", "Virtual-1", "0,0 1200x800", "none")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.runtime / "desktop-shell-recording.conf").exists())
        picker = (ROOT / "modules/desktop/hyprland/shell/qml/ScreenshotPicker.qml").read_text()
        self.assertIn("id: recordingStart", picker)
        self.assertIn("picker.open = true;", picker)
        self.assertIn("RECORDING START FAILED", picker)

    def test_recording_start_waits_for_encoder_output(self):
        """A phase marker alone is not an initialized recording."""
        self.executable(
            "systemctl",
            """
if [ "$1" = --user ] && [ "$2" = start ]; then
  printf 'recording\\n42\\n%s/missing.mp4\\n' "$XDG_RUNTIME_DIR" > "$XDG_RUNTIME_DIR/desktop-shell-recording.state"
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
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("did not become active", result.stderr)

    def test_recording_output_is_private(self):
        """The service and direct recording entry point both restrict file access."""
        self.env["DESKTOP_SHELL_RECORDING_DIR"] = str(self.home / "recordings")
        configuration = self.runtime / "desktop-shell-recording.conf"
        configuration.write_text("Virtual-1\n0,0 1200x800\nnone\n")
        self.executable(
            "wf-recorder",
            'for argument do output="$argument"; done\nprintf "video-frame" > "$output"\n',
        )
        result = self.run_script(SCRIPTS / "record-region.sh")
        self.assertEqual(result.returncode, 0, result.stderr)
        captures = list((self.home / "recordings").glob("Recording-*.mp4"))
        self.assertEqual(len(captures), 1)
        self.assertEqual(captures[0].stat().st_mode & 0o777, 0o600)
        config = (ROOT / "modules/desktop/hyprland/shell/default.nix").read_text()
        recording_service = config.split("desktop-shell-recording = {", 1)[1].split("desktop-shell-lock = {", 1)[0]
        self.assertIn('UMask = "0077";', recording_service)

    @unittest.skipUnless(shutil.which("flock"), "GNU flock is required for operation-lock integration")
    def test_theme_cancellation_prevents_worker_build(self):
        """Cancelled work may never re-enter the build or activation phase."""
        operation = self.state / "desktop-shell/theme-operation"
        operation.mkdir(parents=True)
        (operation / "phase").write_text("cancelled\n")
        (operation / "output.log").touch()
        marker = self.home / "nh-called"
        self.executable("nh", 'printf "%s\\n" "$*" >> "$NH_MARKER"\n')
        self.env["NH_MARKER"] = str(marker)
        source = self.theme_runner(operation)
        self.executable("jq", "exit 0\n")
        result = self.run_script(source, "switch", "carbon", "--worker")
        self.assertEqual(result.returncode, 130, result.stderr)
        self.assertFalse(marker.exists())
        self.assertEqual((operation / "phase").read_text().strip(), "cancelled")

    @unittest.skipUnless(shutil.which("flock"), "GNU flock is required for operation-lock integration")
    def test_theme_cancellation_after_build_blocks_activation(self):
        """A cancelled builder cannot cross the activation boundary."""
        operation = self.state / "desktop-shell/theme-operation"
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
        source = self.theme_runner(operation)
        result = self.run_script(source, "switch", "carbon", "--worker")
        self.assertEqual(result.returncode, 130, result.stderr)
        calls = marker.read_text()
        self.assertIn("os build", calls)
        self.assertNotIn("os switch", calls)
        self.assertEqual((operation / "phase").read_text().strip(), "cancelled")

    @unittest.skipUnless(shutil.which("flock"), "GNU flock is required for theme launch")
    def test_theme_launcher_starts_independent_user_service(self):
        """The chooser returns after systemd accepts an independent worker."""
        operation = self.state / "desktop-shell/theme-operation"
        self.executable("jq", "exit 0\n")
        self.executable("systemctl", "exit 1\n")
        arguments = self.home / "systemd-run-arguments"
        self.env["SYSTEMD_RUN_ARGUMENTS"] = str(arguments)
        self.executable("systemd-run", 'printf "%s\\n" "$@" > "$SYSTEMD_RUN_ARGUMENTS"\n')
        source = self.theme_runner(operation)

        result = self.run_script(source, "switch", "carbon")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((operation / "phase").read_text().strip(), "preparing")
        invocation = arguments.read_text().splitlines()
        self.assertIn("--user", invocation)
        self.assertIn("--service-type=exec", invocation)
        self.assertIn("--collect", invocation)
        self.assertIn("--unit=desktop-shell-theme-apply", invocation)
        self.assertNotIn("--scope", invocation)
        self.assertEqual(invocation[-3:], ["switch", "carbon", "--worker"])

    @unittest.skipUnless(shutil.which("flock"), "GNU flock is required for theme cancellation")
    def test_theme_cancel_publishes_state_before_stopping_service(self):
        """The worker observes cancellation before systemd stops its service."""
        operation = self.state / "desktop-shell/theme-operation"
        operation.mkdir(parents=True)
        (operation / "phase").write_text("building\n")
        self.executable(
            "systemctl",
            'test "$(cat "$THEME_OPERATION_DIR/phase")" = cancelled || exit 5\nprintf "%s\\n" "$*" > "$XDG_RUNTIME_DIR/stopped-unit"\n',
        )
        self.env["THEME_OPERATION_DIR"] = str(operation)
        source = self.theme_runner(operation)

        result = self.run_script(source, "cancel")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((operation / "phase").read_text().strip(), "cancelled")
        self.assertEqual((self.runtime / "stopped-unit").read_text().strip(), "--user stop desktop-shell-theme-apply.service")

    @unittest.skipUnless(shutil.which("flock"), "GNU flock is required for theme build")
    def test_theme_failed_build_does_not_attempt_activation(self):
        """A real build failure remains an error and never switches systems."""
        operation = self.state / "desktop-shell/theme-operation"
        operation.mkdir(parents=True)
        (operation / "phase").write_text("preparing\n")
        (operation / "output.log").touch()
        self.executable("jq", "exit 0\n")
        self.executable("nh", 'if [ "$2" = build ]; then exit 42; fi\ntouch "$NH_MARKER"\n')
        self.env["NH_MARKER"] = str(self.home / "activated")
        source = self.theme_runner(operation)

        result = self.run_script(source, "switch", "carbon", "--worker")
        self.assertEqual(result.returncode, 42)
        self.assertEqual((operation / "phase").read_text().strip(), "failed")
        self.assertFalse((self.home / "activated").exists())

    def test_screenshot_copy_failure_does_not_report_success(self):
        """Clipboard failure leaves the frozen capture retryable."""
        snapshot = self.runtime / "desktop-shell-capture-12345678.png"
        snapshot.write_bytes(b"source-frame")
        pictures = self.home / "pictures"
        self.env["XDG_PICTURES_DIR"] = str(pictures)
        self.executable(
            "magick",
            """
if [ "$1" = identify ]; then
  printf '120 120\n'
else
  for argument do output="$argument"; done
  printf 'saved-frame' > "$output"
fi
""",
        )
        self.executable("wl-copy", "exit 47\n")
        notified = self.runtime / "notified"
        self.env["CAPTURE_NOTIFY_MARKER"] = str(notified)
        self.executable("systemd-run", 'touch "$CAPTURE_NOTIFY_MARKER"\n')

        result = self.run_script(SCRIPTS / "frozen-capture.sh", "copy", str(snapshot), "0", "0", "80", "80")
        self.assertNotEqual(result.returncode, 0, result.stderr)
        self.assertTrue(snapshot.exists())
        self.assertFalse(notified.exists())

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
