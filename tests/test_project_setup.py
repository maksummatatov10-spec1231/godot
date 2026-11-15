import importlib.util
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("project_setup", ROOT / "tools/project_setup.py")
setup = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(setup)


class ProjectSetupTests(unittest.TestCase):
    def test_enables_only_real_extension_resources_not_templates(self):
        with tempfile.TemporaryDirectory() as temp:
            project = Path(temp)
            (project / "native").mkdir()
            (project / "native/example.gdextension").touch()
            (project / "native/optional.gdextension.in").touch()
            setup.prepare_extensions(project)
            self.assertEqual((project / ".godot/extension_list.cfg").read_text(),
                             "res://native/example.gdextension\n")

    def test_removes_stale_entries_and_ignores_import_cache(self):
        with tempfile.TemporaryDirectory() as temp:
            project = Path(temp)
            (project / ".godot").mkdir()
            (project / ".godot/extension_list.cfg").write_text("res://removed.gdextension\n")
            (project / ".godot/cached.gdextension").touch()
            setup.prepare_extensions(project)
            self.assertEqual((project / ".godot/extension_list.cfg").read_text(), "")

    def test_rejects_newlines_in_resource_paths(self):
        with tempfile.TemporaryDirectory() as temp:
            project = Path(temp)
            (project / "bad\nname.gdextension").touch()
            with self.assertRaises(RuntimeError):
                setup.prepare_extensions(project)


if __name__ == "__main__":
    unittest.main()
