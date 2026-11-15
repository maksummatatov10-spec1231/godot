"""Negative fixtures exercise the sky/foreground preservation assertions."""
from pathlib import Path
import sys
import tempfile
import unittest

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from verify_cloud_images import verify, verify_terrain


class CloudImagesTests(unittest.TestCase):
    def check_images(self, mutate=None):
        with tempfile.TemporaryDirectory() as directory:
            sky = Image.new('RGB', (960, 540), '#7394b0')
            ImageDraw.Draw(sky).rectangle((455, 294, 503, 396), fill='#693511')
            clouds = sky.copy()
            ImageDraw.Draw(clouds).ellipse((10, 100, 550, 270), fill='white')
            if mutate:
                mutate(clouds, sky)
            a, b = Path(directory) / 'sky.png', Path(directory) / 'clouds.png'
            sky.save(a)
            clouds.save(b)
            return verify(a, b)

    def test_black_terrain_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'terrain.png'
            Image.new('RGB', (960, 540), 'black').save(path)
            with self.assertRaisesRegex(RuntimeError, 'Terrain material is mostly black'):
                verify_terrain(path)

    def test_clouds_preserve_sky_and_foreground(self):
        self.assertEqual(self.check_images()['reference_error'], 0)

    def test_black_background_regression_rejected(self):
        with self.assertRaisesRegex(RuntimeError, 'clear sky with black'):
            self.check_images(lambda clouds, _: ImageDraw.Draw(clouds).rectangle(
                (650, 140, 940, 250), fill='black'))

    def test_destroyed_foreground_rejected(self):
        with self.assertRaisesRegex(RuntimeError, 'foreground reference'):
            self.check_images(lambda clouds, _: ImageDraw.Draw(clouds).rectangle(
                (455, 294, 503, 396), fill='black'))

    def test_missing_clouds_rejected(self):
        with self.assertRaisesRegex(RuntimeError, 'No visible cloud'):
            self.check_images(lambda clouds, sky: clouds.paste(sky))


if __name__ == '__main__':
    unittest.main()
