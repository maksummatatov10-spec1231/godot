"""Pixel-comparison gate for the local-vs-full-world shadow regression."""
from pathlib import Path
import sys
import tempfile
import unittest

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from benchmark_lantern import changed_pixels


class LanternLocalityGate(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.first = Path(self.temporary.name) / 'first.png'
        self.second = Path(self.temporary.name) / 'second.png'
        Image.new('RGB', (8, 8), (100, 100, 100)).save(self.first)

    def test_identical_images_have_no_changed_pixels(self):
        self.second.write_bytes(self.first.read_bytes())
        self.assertEqual(changed_pixels(self.first, self.second), 0)

    def test_threshold_ignores_subthreshold_sunlight_rounding(self):
        Image.new('RGB', (8, 8), (112, 100, 100)).save(self.second)
        self.assertEqual(changed_pixels(self.first, self.second), 0)

    def test_missing_shadow_pixels_cannot_hide_in_average_error(self):
        image = Image.new('RGB', (8, 8), (100, 100, 100))
        image.putpixel((4, 4), (100, 113, 100))
        image.save(self.second)
        self.assertEqual(changed_pixels(self.first, self.second), 1)

    def test_different_resolutions_are_rejected(self):
        Image.new('RGB', (9, 8)).save(self.second)
        with self.assertRaises(RuntimeError):
            changed_pixels(self.first, self.second)
