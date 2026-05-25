import importlib.util
import os
import tempfile
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

    def test_release_version_must_match_script_version(self):
        os.environ["RELEASE_VERSION"] = "9.9.9"
        self.addCleanup(os.environ.pop, "RELEASE_VERSION", None)

        with self.assertRaisesRegex(RuntimeError, "release"):
            self.um.validate_release_version("1.4.0")

    def test_read_bskeytools_version(self):
        version = self.um.read_bskeytools_version()
        self.assertRegex(version, r"^\d+\.\d+\.\d+$")

    def test_read_bscleanvirus_version(self):
        version = self.um.read_bscleanvirus_version()
        self.assertRegex(version, r"^\d+\.\d+")

    def test_write_version_dat(self):
        with tempfile.NamedTemporaryFile(mode="r", suffix=".dat", delete=False) as tmp:
            tmp_path = tmp.name

        try:
            original = self.um.VERSION_DAT
            self.um.VERSION_DAT = tmp_path
            self.addCleanup(setattr, self.um, "VERSION_DAT", original)

            self.um.write_version_dat("1.4.0", "2.2")

            with open(tmp_path, encoding="utf-8") as f:
                lines = f.read().splitlines()
            self.assertEqual(lines[0], "1.4.0")
            self.assertEqual(lines[1], "2.2")
        finally:
            os.unlink(tmp_path)


if __name__ == "__main__":
    unittest.main()
