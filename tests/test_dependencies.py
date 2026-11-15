import hashlib
import importlib.util
import io
from pathlib import Path
import tarfile
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("dependencies", ROOT / "tools/dependencies.py")
dependencies = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(dependencies)


def archive_for(name="root/sub/file.txt", kind=tarfile.REGTYPE):
    output = io.BytesIO()
    with tarfile.open(fileobj=output, mode="w:gz") as archive:
        entry = tarfile.TarInfo(name)
        entry.type = kind
        if kind == tarfile.REGTYPE:
            entry.size = 5
            archive.addfile(entry, io.BytesIO(b"hello"))
        else:
            entry.linkname = "/outside"
            archive.addfile(entry)
    return output.getvalue()


class DependencyTests(unittest.TestCase):
    def test_extracts_regular_files_and_strips_archive_root(self):
        with tempfile.TemporaryDirectory() as temp:
            dependencies.extract(archive_for(), temp)
            self.assertEqual((Path(temp) / "sub/file.txt").read_bytes(), b"hello")

    def test_rejects_absolute_and_parent_paths(self):
        for name in ["/absolute", "root/../escape", "../escape"]:
            with self.subTest(name=name), tempfile.TemporaryDirectory() as temp:
                with self.assertRaisesRegex(RuntimeError, "unsafe"):
                    dependencies.extract(archive_for(name), temp)

    def test_rejects_symlinks_hardlinks_and_special_files(self):
        for kind in [tarfile.SYMTYPE, tarfile.LNKTYPE, tarfile.FIFOTYPE]:
            with self.subTest(kind=kind), tempfile.TemporaryDirectory() as temp:
                with self.assertRaises(RuntimeError):
                    dependencies.extract(archive_for(kind=kind), temp)

    def test_existing_directory_symlink_cannot_escape_destination(self):
        with tempfile.TemporaryDirectory() as temp, tempfile.TemporaryDirectory() as outside:
            (Path(temp) / "sub").symlink_to(outside, target_is_directory=True)
            with self.assertRaisesRegex(RuntimeError, "existing symlink"):
                dependencies.extract(archive_for(), temp)
            self.assertFalse((Path(outside) / "file.txt").exists())

    def test_verified_cache_avoids_network(self):
        data = b"verified dependency"
        digest = hashlib.sha256(data).hexdigest()
        with tempfile.TemporaryDirectory() as temp:
            (Path(temp) / digest).write_bytes(data)
            with patch.object(dependencies, "CACHE", Path(temp)), patch.object(
                dependencies.urllib.request, "urlopen"
            ) as network:
                self.assertEqual(dependencies.fetch({"sha256": digest, "url": "unused"}), data)
                network.assert_not_called()

    def test_mismatched_download_is_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            with patch.object(dependencies, "CACHE", Path(temp)), patch.object(
                dependencies.urllib.request, "urlopen", return_value=io.BytesIO(b"bad bytes")
            ):
                with self.assertRaisesRegex(RuntimeError, "SHA-256 mismatch"):
                    dependencies.fetch({"sha256": "0" * 64, "url": "https://example.invalid"})
                self.assertFalse((Path(temp) / ("0" * 64)).exists())

    def test_corrupt_cache_is_replaced_only_with_verified_data(self):
        data = b"verified dependency"
        digest = hashlib.sha256(data).hexdigest()
        with tempfile.TemporaryDirectory() as temp:
            (Path(temp) / digest).write_bytes(b"corrupt")
            with patch.object(dependencies, "CACHE", Path(temp)), patch.object(
                dependencies.urllib.request, "urlopen", return_value=io.BytesIO(data)
            ):
                self.assertEqual(dependencies.fetch({"sha256": digest, "url": "unused"}), data)
                self.assertEqual((Path(temp) / digest).read_bytes(), data)


if __name__ == "__main__":
    unittest.main()
