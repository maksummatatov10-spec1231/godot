"""Release ZIP includes source assets, never another machine's Godot cache."""
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import zipfile

MODULE = Path(__file__).resolve().parents[1] / 'tools/package_forest.py'
spec = importlib.util.spec_from_file_location('forest_package', MODULE)
package_tool = importlib.util.module_from_spec(spec)
spec.loader.exec_module(package_tool)


class ForestPackageTests(unittest.TestCase):
    def test_package_excludes_cache_and_pins_every_member(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            game = root / 'forest_game'
            (game / '.godot').mkdir(parents=True)
            (game / 'project.godot').write_text('config_version=5')
            (game / 'README.md').write_text('Game instructions')
            (game / '.godot/import-cache').write_text('not portable')
            destination = root / 'release/game.zip'
            with patch.object(package_tool, 'ROOT', root), patch.object(
                    package_tool.subprocess, 'check_output', return_value='test-commit\n'):
                manifest = package_tool.package(destination)
            with zipfile.ZipFile(destination) as archive:
                self.assertFalse(any('/.godot/' in name for name in archive.namelist()))
                recorded = json.loads(archive.read('WardenForest/BUILD_MANIFEST.json'))
                self.assertEqual(recorded['repository_commit'], 'test-commit')
                for entry in recorded['files']:
                    data = archive.read('WardenForest/' + entry['path'])
                    self.assertEqual(hashlib.sha256(data).hexdigest(), entry['sha256'])
            self.assertEqual(len(manifest['files']), 2)
            self.assertTrue(destination.with_suffix('.zip.sha256').exists())


if __name__ == '__main__':
    unittest.main()
