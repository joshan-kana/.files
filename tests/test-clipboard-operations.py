"""Clipboard pin lifecycle with isolated cliphist and Wayland mocks."""

import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts/desktop-shell/clipboard-operations.py"


class ClipboardOperationsTests(unittest.TestCase):
    """Exercise pin storage without accessing the real clipboard."""

    def setUp(self):
        """Create a sandboxed clipboard history and pin directory."""
        self.temp = tempfile.TemporaryDirectory(prefix="clipboard-operations-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.state = self.root / "state"
        self.state.mkdir()
        self.env = os.environ.copy()
        self.env.update(
            {
                "HOME": str(self.root),
                "XDG_STATE_HOME": str(self.state),
                "PATH": str(self.bin) + os.pathsep + self.env.get("PATH", ""),
            }
        )
        cliphist = self.bin / "cliphist"
        cliphist.write_text(
            "#!/bin/sh\n"
            'case "$1" in\n'
            "list) printf '42\\tExample pinned text\\n' ;;\n"
            "decode) [ \"$2\" = 42 ] || exit 1; printf 'Example pinned text' ;;\n"
            'delete) cat > "$XDG_STATE_HOME/deleted" ;;\n'
            "*) exit 2 ;;\n"
            "esac\n"
        )
        cliphist.chmod(0o755)
        copy = self.bin / "wl-copy"
        copy.write_text('#!/bin/sh\ncat > "$XDG_STATE_HOME/copied"\n')
        copy.chmod(0o755)

    def execute(self, *args):
        """Invoke the command with sandboxed system utilities."""
        return subprocess.run(
            [sys.executable, str(SCRIPT), *args],
            env=self.env,
            capture_output=True,
            text=False,
            timeout=12,
        )

    def test_pin_list_copy_unpin_and_permissions(self):
        """Retained content remains private, readable and removable."""
        self.assertEqual(self.execute("pin", "42", "TEXT").returncode, 0)
        output = self.execute("list")
        self.assertEqual(output.returncode, 0)
        first = output.stdout.decode().splitlines()[0]
        identity = first.split("\t", 1)[0]
        self.assertTrue(identity.startswith("pin:"))
        self.assertIn("Example pinned text", first)
        folder = self.state / "desktop-shell" / "clipboard-pins"
        self.assertEqual(folder.stat().st_mode & 0o777, 0o700)
        for path in folder.iterdir():
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)
        self.assertEqual(self.execute("read", identity).stdout, b"Example pinned text")
        self.assertEqual(self.execute("copy", identity).returncode, 0)
        self.assertEqual((self.state / "copied").read_bytes(), b"Example pinned text")
        self.assertEqual(self.execute("unpin", identity).returncode, 0)
        self.assertTrue(self.execute("list").stdout.decode().startswith("42\t"))
        self.assertEqual(list(folder.iterdir()), [])

    def test_delete_history_and_bad_identifiers_fail_closed(self):
        """Reject invalid identities and delete only selected history rows."""
        self.assertEqual(self.execute("delete", "42").returncode, 0)
        self.assertEqual((self.state / "deleted").read_text(), "42\n")
        for args in [
            ("pin", "42;rm -rf /", "TEXT"),
            ("pin", "42", "IMAGE"),
            ("delete", "../../../secret"),
            ("copy", "pin:abc"),
            ("read", "pin:" + "0" * 64),
        ]:
            with self.subTest(args=args):
                self.assertNotEqual(self.execute(*args).returncode, 0)


if __name__ == "__main__":
    unittest.main()
