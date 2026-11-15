import importlib.util
import tempfile
import unittest
import zipfile
from pathlib import Path
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('extract_assets', Path(__file__).resolve().parents[1] / 'tools/extract_asset_library.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class AssetExtractionTests(unittest.TestCase):
    def test_rejects_unsafe_paths(self):
        with tempfile.TemporaryDirectory() as tmp:
            for name in ['../escape', '/absolute', 'dir/../../escape', 'C:/drive', 'dir\\file', 'nul\x00file']:
                with self.subTest(name=name), self.assertRaises(ValueError):
                    module.safe_target(Path(tmp), name)

    def test_rejects_symlink_parent(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / 'root'; root.mkdir()
            (root / 'link').symlink_to(Path(tmp), target_is_directory=True)
            with self.assertRaises(ValueError):
                module.safe_target(root, 'link/escape')

    def test_extracts_regular_file(self):
        with tempfile.TemporaryDirectory() as tmp:
            archive = Path(tmp) / 'test.zip'; dest = Path(tmp) / 'out'
            with zipfile.ZipFile(archive, 'w') as z:
                z.writestr('folder/', b'')
                z.writestr('folder/file.txt', 'hello')
            budget = {'bytes':0, 'entries':0}
            module.extract_zip(archive, dest, budget)
            self.assertEqual((dest / 'folder/file.txt').read_text(), 'hello')
            self.assertEqual(budget, {'bytes':5, 'entries':2})

    def test_rejects_archive_symlink(self):
        with tempfile.TemporaryDirectory() as tmp:
            archive = Path(tmp) / 'test.zip'
            with zipfile.ZipFile(archive, 'w') as z:
                entry = zipfile.ZipInfo('link'); entry.create_system = 3
                entry.external_attr = 0o120777 << 16
                z.writestr(entry, '../escape')
            with self.assertRaises(ValueError):
                module.extract_zip(archive, Path(tmp) / 'out', {'bytes':0, 'entries':0})

    def test_rejects_duplicate_targets(self):
        with tempfile.TemporaryDirectory() as tmp:
            archive = Path(tmp) / 'test.zip'
            with zipfile.ZipFile(archive, 'w') as z:
                z.writestr('folder/file', 'a')
                z.writestr('folder/./file', 'b')
            with self.assertRaises(ValueError):
                module.extract_zip(archive, Path(tmp) / 'out', {'bytes':0, 'entries':0})

    def test_budget_checked_before_writing(self):
        with tempfile.TemporaryDirectory() as tmp:
            archive = Path(tmp) / 'test.zip'; dest = Path(tmp) / 'out'
            with zipfile.ZipFile(archive, 'w') as z:
                z.writestr('file', 'oversize')
            with patch.object(module, 'LIMIT', 2), self.assertRaises(ValueError):
                module.extract_zip(archive, dest, {'bytes':0, 'entries':0})
            self.assertFalse((dest / 'file').exists())

    def test_never_overwrites_file(self):
        with tempfile.TemporaryDirectory() as tmp:
            archive = Path(tmp) / 'test.zip'; dest = Path(tmp) / 'out'; dest.mkdir()
            (dest / 'file').write_text('original')
            with zipfile.ZipFile(archive, 'w') as z:
                z.writestr('file', 'replacement')
            with self.assertRaises(FileExistsError):
                module.extract_zip(archive, dest, {'bytes':0, 'entries':0})
            self.assertEqual((dest / 'file').read_text(), 'original')


if __name__ == '__main__':
    unittest.main()
