"""Read-only regression coverage for the command palette's private index."""

import importlib.util
import json
import os
import sqlite3
import tempfile
import unittest
from pathlib import Path
from unittest import mock


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

    def test_bookmark_discovery_uses_profile_layout_not_browser_names(self):
        """Discover new and removed browser profiles without code changes."""
        config = self.base / ".config"
        chromium = config / "AnyPublisher" / "NewBrowser" / "Default" / "Bookmarks"
        chromium.parent.mkdir(parents=True)
        chromium.write_text(
            json.dumps(
                {"roots": {"bookmark_bar": {"children": [{"type": "url", "name": "Added Browser Link", "url": "https://example.com/new"}]}}}
            )
        )
        gecko = self.base / ".unlisted-browser"
        profile = gecko / "Profiles" / "special.release"
        profile.mkdir(parents=True)
        (gecko / "profiles.ini").write_text("[Profile0]\nName=Default\nIsRelative=1\nPath=Profiles/special.release\n")
        with sqlite3.connect(profile / "places.sqlite") as connection:
            connection.execute("CREATE TABLE moz_places (id INTEGER PRIMARY KEY, url TEXT)")
            connection.execute("CREATE TABLE moz_bookmarks (type INTEGER, fk INTEGER, title TEXT)")
            connection.execute("INSERT INTO moz_places VALUES (1, 'https://example.org/gecko')")
            connection.execute("INSERT INTO moz_bookmarks VALUES (1, 1, 'Discovered Gecko Bookmark')")
        with (
            mock.patch.object(Path, "home", return_value=self.base),
            mock.patch.dict(
                os.environ,
                {
                    "XDG_CONFIG_HOME": str(config),
                    "XDG_DATA_HOME": str(self.base / ".local/share"),
                },
            ),
        ):
            sources = list(self.palette.bookmark_sources())
            self.assertEqual(len(sources), 2)
            self.palette.index()
            self.assertEqual(self.palette.query("Added Browser Link")[0]["kind"], "bookmark")
            self.assertEqual(self.palette.query("Discovered Gecko Bookmark")[0]["kind"], "bookmark")
            chromium.unlink()
            (profile / "places.sqlite").unlink()
            self.palette.index()
            self.assertEqual(self.palette.query("Added Browser Link"), [])
            self.assertEqual(self.palette.query("Discovered Gecko Bookmark"), [])

    def test_secret_directories_are_not_browser_profile_sources(self):
        """A misleading browser profile under private secrets is never read."""
        secret = self.base / ".secrets"
        profile = secret / "Default"
        profile.mkdir(parents=True)
        (profile / "Bookmarks").write_text(
            json.dumps(
                {"roots": {"bookmark_bar": {"children": [{"type": "url", "name": "Secret Bookmark", "url": "https://example.invalid"}]}}}
            )
        )
        with (
            mock.patch.object(Path, "home", return_value=self.base),
            mock.patch.dict(os.environ, {"XDG_CONFIG_HOME": str(self.base / ".config")}),
        ):
            self.palette.index()
            self.assertEqual(self.palette.query("Secret Bookmark"), [])

    def test_new_browser_directories_are_observable_without_restart(self):
        """Profile ancestry is monitored before any bookmarks are written."""
        custom = self.base / "custom-config"
        vendor = custom / "PublisherWithoutBrowserList"
        new_browser = vendor / "NewApp"
        new_browser.mkdir(parents=True)
        with (
            mock.patch.object(Path, "home", return_value=self.base),
            mock.patch.dict(os.environ, {"XDG_CONFIG_HOME": str(custom), "XDG_DATA_HOME": str(self.base / "custom-data")}),
        ):
            watched = set(self.palette.browser_watch_containers())
            self.assertIn(custom, watched)
            self.assertIn(vendor, watched)
            self.assertIn(new_browser, watched)
            self.assertNotIn(self.base / ".secrets", watched)

    def test_explicit_open_with_uses_xdg_data_applications(self):
        """Resolve installed desktop entries in the configured XDG data home."""
        data = self.base / "xdg-data"
        application = data / "applications" / "new-browser.desktop"
        application.parent.mkdir(parents=True)
        application.write_text("[Desktop Entry]\\nType=Application\\nName=Browser\\nExec=example %u\\n")
        with (
            mock.patch.object(Path, "home", return_value=self.base),
            mock.patch.dict(os.environ, {"XDG_DATA_HOME": str(data), "XDG_DATA_DIRS": ""}),
        ):
            self.assertEqual(self.palette.installed_desktop_entry("new-browser"), application)
            self.assertIsNone(self.palette.installed_desktop_entry("../new-browser"))

    def test_bookmark_files_respect_xdg_paths(self):
        """Non-default XDG directories are first-class discovery roots."""
        alternate = self.base / "custom-config" / "UnknownApp" / "Default"
        alternate.mkdir(parents=True)
        (alternate / "Bookmarks").write_text(
            json.dumps(
                {"roots": {"bookmark_bar": {"children": [{"type": "url", "name": "XDG Custom Browser", "url": "https://example.net"}]}}}
            )
        )
        with (
            mock.patch.object(Path, "home", return_value=self.base),
            mock.patch.dict(
                os.environ,
                {
                    "XDG_CONFIG_HOME": str(self.base / "custom-config"),
                    "XDG_DATA_HOME": str(self.base / "custom-data"),
                },
            ),
        ):
            self.palette.index()
            item = self.palette.query("XDG Custom Browser")
            self.assertEqual(len(item), 1)
            self.assertEqual(item[0]["url"], "https://example.net")

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
