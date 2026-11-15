"""Regression-check the real sky/cloud captures; never a substitute for visual review."""
import argparse
from pathlib import Path

from PIL import Image, ImageChops, ImageStat


def verify(sky_path: Path, clouds_path: Path) -> dict:
    with Image.open(sky_path) as source:
        sky = source.convert('RGB')
    with Image.open(clouds_path) as source:
        clouds = source.convert('RGB')
    if sky.size != (960, 540) or clouds.size != sky.size:
        raise RuntimeError('Expected matching actual 960x540 viewport captures')
    # Fixed integration fixture: no clouds can cover the nearby central pillar.
    reference = (460, 310, 495, 385)
    reference_error = max(ImageStat.Stat(ImageChops.difference(
        sky.crop(reference), clouds.crop(reference))).mean)
    if reference_error > 8:
        raise RuntimeError('Cloud compositor lost/modified the foreground reference')
    # Black base-color regression is checked away from the white clouds and HUD.
    clear_sky = clouds.crop((650, 140, 940, 250))
    black_fraction = sum(max(pixel) < 8 for pixel in clear_sky.get_flattened_data()) / (
        clear_sky.width * clear_sky.height)
    if black_fraction > 0.05:
        raise RuntimeError('Cloud compositor replaced the clear sky with black')
    cloud_difference = sum(ImageStat.Stat(ImageChops.difference(
        sky.crop((0, 110, 600, 260)), clouds.crop((0, 110, 600, 260)))).mean) / 3
    if cloud_difference < 5:
        raise RuntimeError('No visible cloud contribution in the expected sky region')
    return {'reference_error': reference_error, 'black_fraction': black_fraction,
            'cloud_difference': cloud_difference}


def verify_terrain(path: Path) -> dict:
    with Image.open(path) as source:
        image = source.convert('RGB')
    ground = image.crop((30, 400, 930, 530))
    black_fraction = sum(max(pixel) < 8 for pixel in ground.get_flattened_data()) / (
        ground.width * ground.height)
    if black_fraction > 0.4:
        raise RuntimeError('Terrain material is mostly black; check referenced texture layers')
    return {'ground_black_fraction': black_fraction}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--directory', type=Path, default=Path('docs/evidence/forward-plus'))
    args = parser.parse_args()
    print('CLOUD_IMAGE_REGRESSION_OK', verify(
        args.directory / 'sky-only.png', args.directory / 'clouds-only.png'),
        verify_terrain(args.directory / 'terrain-clouds.png'))
