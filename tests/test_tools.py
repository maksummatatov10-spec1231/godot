import importlib.util
from pathlib import Path
import subprocess
import sys
import tempfile
import tomllib
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
SPEC = importlib.util.spec_from_file_location("check", ROOT / "tools/check.py")
check = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(check)


class ToolTests(unittest.TestCase):
    def setUp(self):
        setup_patch = patch("project_setup.prepare_extensions")
        setup_patch.start()
        self.addCleanup(setup_patch.stop)

    def test_explicit_engine_path_has_priority(self):
        with patch.dict(check.os.environ, {"GODOT4_BIN": "/custom/godot"}), patch.object(
            check.shutil, "which", return_value="/custom/godot"
        ):
            self.assertEqual(check.resolve_engine(), "/custom/godot")

    def test_local_engine_fallback(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / ".godot-version").write_text("4.7.2-stable\n")
            local = root / ".tools/godot/Godot_v4.7.2-stable_linux.x86_64"
            local.parent.mkdir(parents=True)
            local.write_text("fixture")
            local.chmod(0o755)
            with patch.object(check, "ROOT", root), patch.object(
                check.sys, "platform", "linux"
            ), patch.dict(check.os.environ, {}, clear=True), patch.object(
                check.shutil, "which", return_value=None
            ):
                self.assertEqual(check.resolve_engine(), str(local))
                local.unlink()
                self.assertIsNone(check.resolve_engine())

    def test_version_is_exact_not_a_minor_or_beta_match(self):
        self.assertTrue(check.engine_matches("4.7.2.stable.official.ed1daf0bf\n", "4.7.2-stable"))
        for version in ["4.7.1.stable.official.x", "4.8.beta3.official.x", "4.7.20.stable.x"]:
            self.assertFalse(check.engine_matches(version, "4.7.2-stable"))

    def test_godot_errors_fail_even_on_zero_exit(self):
        for output in ["SCRIPT ERROR: broken", "ERROR: broken", "Parse Error: bad script"]:
            with self.subTest(output=output), tempfile.TemporaryDirectory() as temp:
                with patch.object(check, "ARTIFACTS", Path(temp)), patch.object(
                    check.subprocess, "run", return_value=subprocess.CompletedProcess([], 0, output)
                ):
                    with self.assertRaises(RuntimeError):
                        check.run_step("fixture", ["fake-engine"])

    def test_nonzero_exit_fails(self):
        with tempfile.TemporaryDirectory() as temp:
            with patch.object(check, "ARTIFACTS", Path(temp)), patch.object(
                check.subprocess, "run", return_value=subprocess.CompletedProcess([], 1, "failed")
            ):
                with self.assertRaises(RuntimeError):
                    check.run_step("fixture", ["fake-engine"])

    def test_timeout_fails_and_preserves_partial_log(self):
        with tempfile.TemporaryDirectory() as temp:
            with patch.object(check, "ARTIFACTS", Path(temp)), patch.object(
                check.subprocess, "run",
                side_effect=subprocess.TimeoutExpired("fake", 1, output=b"partial")
            ):
                with self.assertRaisesRegex(RuntimeError, "timed out"):
                    check.run_step("fixture", ["fake-engine"], timeout=1)
                self.assertEqual((Path(temp) / "fixture.log").read_text(), "partial")

    def test_success_preserves_log(self):
        with tempfile.TemporaryDirectory() as temp:
            with patch.object(check, "ARTIFACTS", Path(temp)), patch.object(
                check.subprocess, "run", return_value=subprocess.CompletedProcess([], 0, "SMOKE_OK")
            ):
                self.assertEqual(check.run_step("fixture", ["fake-engine"]), "SMOKE_OK")

    def test_capture_rejects_blank_wrong_size_and_missing_files(self):
        from PIL import Image
        with tempfile.TemporaryDirectory() as temp:
            image_path = Path(temp) / "test.png"
            Image.new("RGB", (960, 540), "black").save(image_path)
            with self.assertRaisesRegex(RuntimeError, "blank"):
                check.validate_capture(image_path)
            Image.new("RGB", (20, 20), "red").save(image_path)
            with self.assertRaisesRegex(RuntimeError, "size"):
                check.validate_capture(image_path)
            with self.assertRaises(FileNotFoundError):
                check.validate_capture(Path(temp) / "missing.png")

    def test_missing_engine_fails_smoke_instead_of_skipping(self):
        with patch.object(check, "resolve_engine", return_value=None), patch(
            "sys.argv", ["check.py", "smoke"]
        ):
            with self.assertRaisesRegex(RuntimeError, "Godot unavailable"):
                check.main()

    def test_smoke_requires_completion_marker(self):
        with patch.object(check, "resolve_engine", return_value="fake"), patch(
            "sys.argv", ["check.py", "smoke"]
        ), patch.object(check, "run_step", side_effect=[
            "4.7.2.stable.official.fixture", "import complete", "no completion marker"
        ]):
            with self.assertRaisesRegex(RuntimeError, "completion marker"):
                check.main()

    def test_stale_capture_is_removed_even_if_display_is_missing(self):
        with tempfile.TemporaryDirectory() as temp:
            capture = Path(temp) / "lab.png"
            capture.write_bytes(b"old capture")
            with patch.object(check, "ARTIFACTS", Path(temp)), patch.object(
                check, "resolve_engine", return_value="fake"
            ), patch("sys.argv", ["check.py", "visual"]), patch.object(
                check, "run_step", side_effect=["4.7.2.stable.official.fixture", "import complete"]
            ), patch.object(check.sys, "platform", "linux"), patch.dict(
                check.os.environ, {}, clear=True
            ), patch.object(check.shutil, "which", return_value=None):
                with self.assertRaisesRegex(RuntimeError, "xvfb"):
                    check.main()
            self.assertFalse(capture.exists())

    def test_version_pins_and_native_resource_contract(self):
        manifest = tomllib.loads((ROOT / "native/Cargo.toml").read_text())
        toolchain = tomllib.loads((ROOT / "rust-toolchain.toml").read_text())
        self.assertEqual(manifest["dependencies"]["godot"]["version"], "=0.5.5")
        self.assertIn("api-4-7", manifest["dependencies"]["godot"]["features"])
        self.assertEqual(manifest["package"]["rust-version"], "1.94")
        self.assertEqual(toolchain["toolchain"]["channel"], "1.94.0")
        self.assertEqual((ROOT / ".godot-version").read_text().strip(), "4.7.2-stable")
        extension = (ROOT / "native/game_native.gdextension.in").read_text()
        self.assertIn('compatibility_minimum = "4.7"', extension)
        self.assertIn('entry_symbol = "gdext_rust_init"', extension)
        self.assertNotIn("res://../", extension)

    def test_capture_accepts_nonuniform_png(self):
        from PIL import Image, ImageDraw
        with tempfile.TemporaryDirectory() as temp:
            image_path = Path(temp) / "fixture.png"
            image = Image.new("RGB", (960, 540), "black")
            ImageDraw.Draw(image).rectangle((0, 0, 480, 540), fill="white")
            image.save(image_path)
            check.validate_capture(image_path)


if __name__ == "__main__":
    unittest.main()
