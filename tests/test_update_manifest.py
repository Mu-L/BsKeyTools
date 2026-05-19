import importlib.util
import os
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = REPO_ROOT / "scripts" / "update_manifest.py"


def load_update_manifest():
    spec = importlib.util.spec_from_file_location("update_manifest", MODULE_PATH)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class UpdateManifestTests(unittest.TestCase):
    def setUp(self):
        self.um = load_update_manifest()

    def test_release_tag_must_match_script_version(self):
        os.environ["GITHUB_REF_NAME"] = "v9.9.9"
        self.addCleanup(os.environ.pop, "GITHUB_REF_NAME", None)

        with self.assertRaisesRegex(RuntimeError, "release tag"):
            self.um.validate_release_tag_matches_version("1.4.0")

    def test_build_manifest_includes_fallback_base_url_and_sha256(self):
        manifest = self.um.build_manifest(
            version="1.4.0",
            changed_scripts={"BulletScripts/fnUpdater.ms"},
            existing={
                "releaseNote": "note",
                "files": [
                    {
                        "path": "BulletScripts/fnUpdater.ms",
                        "since": "1.3.7",
                        "size": 1,
                    }
                ],
            },
            requires_reinstall=False,
        )

        self.assertIn("fallbackBaseUrl", manifest)
        file_item = next(
            item
            for item in manifest["files"]
            if item["path"] == "BulletScripts/fnUpdater.ms"
        )
        self.assertEqual(file_item["since"], "1.4.0")
        self.assertRegex(file_item["sha256"], r"^[0-9a-f]{64}$")

    def test_release_note_rejects_characters_maxscript_parser_cannot_read(self):
        with self.assertRaisesRegex(RuntimeError, "releaseNote"):
            self.um.validate_release_note_for_maxscript('bad " quote')


if __name__ == "__main__":
    unittest.main()
