"""Read-only regression coverage for the command palette's private index."""

import importlib.util
import json
import os
import tempfile
import unittest
from pathlib import Path


class PaletteIndexTests(unittest.TestCase):
    """Exercise safe indexing against isolated runtime configuration."""

    def setUp(self):
        """Create a private index and a temporary generated runtime file."""
        self.temp = tempfile.TemporaryDirectory(prefix="palette-index-tests-")
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.root = self.base / "roots"
        self.root.mkdir()
        self.config = self.base / "config" / "linux-desktop"
        self.config.mkdir(parents=True)
        self.runtime = self.config / "runtime.json"
        self.runtime.write_text(json.dumps({"palette": {"fileRoots": [str(self.root)]}}))
        self.saved_env = {key: os.environ.get(key) for key in ("LINUX_DESKTOP_RUNTIME", "XDG_CONFIG_HOME")}
        os.environ["LINUX_DESKTOP_RUNTIME"] = str(self.runtime)
        self.addCleanup(self.restore_env)
        source = Path(__file__).resolve().parents[1] / "modules/desktop/hyprland/shell/scripts/palette-search.py"
        spec = importlib.util.spec_from_file_location("palette_search_under_test", source)
        self.palette = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.palette)
        self.palette.BASE = self.base / "cache"
        self.palette.DB = self.palette.BASE / "search.sqlite3"

    def restore_env(self):
        """Restore process environment after each test."""
        for key, value in self.saved_env.items():
            if value is None:
                os.environ.pop(key, None)
            else:
                os.environ[key] = value

    def test_exact_match_is_not_hidden_behind_256_weaker_results(self):
        """Never truncate exact matches before relevance ordering."""
        for i in range(300):
            (self.root / f"a-foo-{i:03d}.txt").touch()
        (self.root / "foo").touch()
        self.palette.index()
        results = self.palette.query("foo")
        self.assertEqual(results[0]["name"], "foo")
        self.assertLessEqual(len(results), 32)

    def test_private_paths_and_unindexed_previews_are_excluded(self):
        """Avoid indexing hidden trees or previewing outside the index."""
        (self.root / "readme.txt").write_text("public")
        (self.root / ".private-readme").write_text("secret")
        (self.root / "node_modules").mkdir()
        (self.root / "node_modules" / "readme.txt").write_text("secret")
        self.palette.index()
        names = [item["name"] for item in self.palette.query("readme")]
        self.assertEqual(names, ["readme.txt"])
        self.assertIsNone(self.palette.preview_indexed_file("/etc/passwd"))

    def test_file_roots_follow_the_current_nix_generated_runtime(self):
        """Track root changes in the Nix-generated configuration."""
        self.assertEqual(self.palette.search_roots(), [self.root])
        another = self.base / "another"
        another.mkdir()
        self.runtime.write_text(json.dumps({"palette": {"fileRoots": [str(another)]}}))
        self.assertEqual(self.palette.search_roots(), [another])
        self.runtime.write_text(json.dumps({"palette": {"fileRoots": []}}))
        self.assertEqual(self.palette.search_roots(), [])


if __name__ == "__main__":
    unittest.main()
