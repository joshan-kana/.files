"""Verify checksum-based GitHub release updates without external requests."""

import importlib.util
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[1] / "scripts/update-github-release.py"
spec = importlib.util.spec_from_file_location("update_github_release", SCRIPT)
updater = importlib.util.module_from_spec(spec)
spec.loader.exec_module(updater)


class BinaryReleaseUpdateTests(unittest.TestCase):
    def test_platform_checksums(self):
        for aggregate in (False, True):
            with self.subTest(aggregate=aggregate), tempfile.TemporaryDirectory() as dirname:
                root = Path(dirname)
                target = root / "overlays/example/default.nix"
                target.parent.mkdir(parents=True)
                target.write_text("""version = "1.0";
asset = {
  aarch64-linux = "linux-arm64";
  x86_64-linux = "linux-amd64";
};
hashes = {
  aarch64-linux = "sha256-old-arm";
  x86_64-linux = "sha256-old-amd";
};
""")
                digest_arm = "a" * 64
                digest_amd = "b" * 64
                artifacts = {
                    "https://api.github.com/repos/owner/repository/releases/latest": json.dumps({"tag_name": "v2.0"}).encode(),
                    "https://github.com/owner/repository/releases/download/v2.0/app-linux-arm64.sha256": digest_arm.encode(),
                    "https://github.com/owner/repository/releases/download/v2.0/app-linux-amd64.sha256": digest_amd.encode(),
                    "https://github.com/owner/repository/releases/download/v2.0/SHA256SUMS.txt": (
                        f"{digest_arm}  app-linux-arm64\n{digest_amd}  app-linux-amd64\n"
                    ).encode(),
                }
                args = ["example", "--repository", "owner/repository", "--asset-pattern", "app-{asset}"]
                args += ["--checksums", "SHA256SUMS.txt"] if aggregate else ["--checksum-suffix", ".sha256"]
                with (
                    patch.object(updater, "fetch", side_effect=artifacts.__getitem__),
                    patch.object(updater.subprocess, "check_output", return_value=str(root)),
                ):
                    updater.main(args)
                content = target.read_text()
                self.assertIn('version = "2.0";', content)
                self.assertIn(updater.sri(digest_arm), content)
                self.assertIn(updater.sri(digest_amd), content)

    def test_mismatched_platforms_fail_without_writing(self):
        with tempfile.TemporaryDirectory() as dirname:
            root = Path(dirname)
            target = root / "overlays/example/default.nix"
            target.parent.mkdir(parents=True)
            original = 'version = "1.0";\nasset = { x86_64-linux = "linux-amd64"; };\nhashes = { };\n'
            target.write_text(original)
            with patch.object(updater.subprocess, "check_output", return_value=str(root)):
                with self.assertRaises(ValueError):
                    updater.main(
                        [
                            "example",
                            "--repository",
                            "owner/repository",
                            "--asset-pattern",
                            "app-{asset}",
                            "--checksums",
                            "SHA256SUMS.txt",
                        ]
                    )
            self.assertEqual(target.read_text(), original)


if __name__ == "__main__":
    unittest.main()
