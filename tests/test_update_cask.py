#!/usr/bin/env python3
"""Tests for the shared cask release updater."""

import importlib.util
import unittest
from pathlib import Path
from unittest import mock

script = Path(__file__).resolve().parents[1] / "scripts" / "update-cask.py"
spec = importlib.util.spec_from_file_location("update_cask", script)
updater = importlib.util.module_from_spec(spec)
spec.loader.exec_module(updater)

OLD = "sha256-" + ("A" * 43) + "="
NEW = "sha256-" + ("B" * 43) + "="


class ReleaseUpdaterTests(unittest.TestCase):
    def test_single_release(self):
        source = 'release = {\n  version = "1.0";\n  hash = "' + OLD + '";\n};'
        result, version = updater.update_single(source, "1.1", None, NEW)
        self.assertEqual(version, "1.0")
        self.assertIn('version = "1.1"', result)
        self.assertIn('hash = "' + NEW + '"', result)

    def test_release_with_independent_build(self):
        source = 'release = {\n  version = "1.0";\n  build = "100";\n  hash = "' + OLD + '";\n};'
        result, _ = updater.update_single(source, "1.1", "110", NEW)
        self.assertIn('version = "1.1"', result)
        self.assertIn('build = "110"', result)

    def test_requires_pinned_release(self):
        with self.assertRaisesRegex(ValueError, "release.version"):
            updater.update_single("not a release", "1.1", None, NEW)

    def test_multi_platform_hashes(self):
        source = (
            'release = {\n  version = "1.0";\n  hashes = {\n'
            f'    "aarch64-darwin" = "{OLD}";\n'
            f'    "aarch64-linux" = "{OLD}";\n'
            f'    "x86_64-linux" = "{OLD}";\n'
            '  };\n};\n'
        )
        urls = {
            "aarch64-darwin": "https://test.example/mac-1.1.zip",
            "aarch64-linux": "https://test.example/arm-1.1.tar.zst",
            "x86_64-linux": "https://test.example/x86-1.1.tar.zst",
        }
        with (
            mock.patch.object(updater, "updated_url", side_effect=lambda s, *_: urls[s]) as resolved,
            mock.patch.object(updater, "prefetch", return_value=NEW) as prefetched,
        ):
            result = updater.update_platform_hashes(
                source, "some-package", "1.1", urls["aarch64-darwin"], NEW
            )
        self.assertIn('version = "1.1"', result)
        self.assertEqual(result.count(NEW), 3)
        self.assertEqual(resolved.call_count, 3)
        self.assertEqual(prefetched.call_count, 2)

    def test_does_not_download_unchanged_archives(self):
        source = (
            'release = { version = "1.0"; hashes = { '
            f'"aarch64-darwin" = "{OLD}"; '
            f'"aarch64-linux" = "{OLD}";'
            ' }; };'
        )
        with (
            mock.patch.object(updater, "updated_url", side_effect=lambda s, *_: f"https://test.example/{s}") as resolved,
            mock.patch.object(updater, "prefetch") as prefetched,
        ):
            result = updater.update_platform_hashes(
                source, "some-package", "1.0", "https://test.example/aarch64-darwin", OLD
            )
        self.assertEqual(result, source)
        self.assertEqual(resolved.call_count, 2)
        prefetched.assert_not_called()

    def test_rejects_wrong_vendor_archive(self):
        source = 'release = { version = "1.0"; hashes = { ' + f'"aarch64-darwin" = "{OLD}";' + ' }; };'
        with mock.patch.object(updater, "updated_url", return_value="https://wrong.test/archive"):
            with self.assertRaisesRegex(ValueError, "no archive matching"):
                updater.update_platform_hashes(source, "other-package", "1.1", "https://expected.test/archive", NEW)

    def test_supports_other_platform_architectures(self):
        source = (
            'release = { version = "1.0"; hashes = { '
            + f'"aarch64-darwin" = "{OLD}"; '
            + f'"riscv64-linux" = "{OLD}";'
            + ' }; };'
        )
        with (
            mock.patch.object(
                updater, "updated_url", side_effect=lambda s, *_: "https://example.test" if s == "aarch64-darwin" else "https://other.test"
            ),
            mock.patch.object(updater, "prefetch", return_value=NEW),
        ):
            result = updater.update_platform_hashes(source, "some-package", "1.1", "https://example.test", NEW)
        self.assertEqual(result.count(NEW), 2)

    def test_rejects_invalid_system_key(self):
        source = 'release = { version = "1.0"; hashes = { ' + f'"not a system" = "{OLD}";' + ' }; };'
        with self.assertRaisesRegex(ValueError, "Invalid platform hash"):
            updater.update_platform_hashes(source, "some-package", "1.1", "https://example.test", NEW)


if __name__ == "__main__":
    unittest.main()
