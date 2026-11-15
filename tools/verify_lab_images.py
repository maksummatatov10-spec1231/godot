"""Assert the known lab state transition; not a general artistic-quality metric."""
from pathlib import Path
from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parents[1]


def verify(before_path, after_path):
    with Image.open(before_path) as source, Image.open(after_path) as target:
        before, after = source.convert("RGB"), target.convert("RGB")
    if before.size != (960, 540) or after.size != before.size:
        raise RuntimeError("lab captures must both be 960x540")
    for image, center in [(before, (480, 300)), (after, (535, 300))]:
        red, green, _blue = image.getpixel(center)
        if not (green > 200 and green > red * 1.5):
            raise RuntimeError(f"expected green player at {center}")
    if after.getpixel((480, 300))[1] >= 100:
        raise RuntimeError("player did not leave its original position")
    bounds = ImageChops.difference(before, after).getbbox()
    if bounds is None or not (450 <= bounds[0] < bounds[2] <= 565
                              and 270 <= bounds[1] < bounds[3] <= 330):
        raise RuntimeError(f"unexpected visual changes outside player region: {bounds}")
    return bounds


if __name__ == "__main__":
    bounds = verify(ROOT / "artifacts/lab.png", ROOT / "artifacts/lab-moved.png")
    print(f"VISUAL_STATE_OK: player x=480 -> 535; changed region {bounds}")
