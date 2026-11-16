"""Strict real-render closeups/animation gate for wildlife and alpha-foot contact."""
import json
import os
from pathlib import Path
import subprocess

from PIL import Image, ImageChops, ImageStat

from capture_lantern import ROOT, game_digest

OUTPUT = ROOT / 'docs/evidence/lantern-contact'


def main():
    OUTPUT.mkdir(exist_ok=True, parents=True)
    report = {'passed': False, 'game_sha256': game_digest(), 'real_render': True,
              'physical_gpu_benchmark': False}
    result_path = OUTPUT / 'result.json'
    result_path.write_text(json.dumps(report, indent=2) + '\n')
    engine = os.environ.get('GODOT4_BIN', str(ROOT / '.tools/godot/Godot_v4.7.2-stable_linux.x86_64'))
    command = ['xvfb-run', '-a', '-s', '-screen 0 1280x720x24', engine,
               '--path', str(ROOT / 'lantern_game'), '--audio-driver', 'Dummy',
               '--fixed-fps', '30', '--resolution', '1280x720',
               '--script', str(ROOT / 'tools/lantern_contact.gd')]
    with (OUTPUT / 'render.log').open('w') as log:
        result = subprocess.run(command, env=dict(os.environ, CONTACT_DIR=str(OUTPUT)),
                                cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, timeout=300)
    text = (OUTPUT / 'render.log').read_text()
    if result.returncode or 'ERROR' in text or 'leaked' in text or 'LANTERN_CONTACT_OK 77' not in text:
        raise RuntimeError(f'Contact renderer exit {result.returncode}\n{text[-6000:]}')
    images = json.loads((OUTPUT / 'capture.json').read_text())['images']
    if len(images) != 77 or report['game_sha256'] != game_digest():
        raise RuntimeError('Stale or incomplete contact capture')
    changes = {}
    for name in images:
        with Image.open(OUTPUT / f'{name}.png') as image:
            if image.size != (1280, 720) or max(ImageStat.Stat(image.convert('RGB')).stddev) < 15:
                raise RuntimeError(f'Invalid closeup: {name}')
    for gait in ['idle', 'walk', 'bound']:
        frames = [Image.open(OUTPUT / f'{gait}-{i:02d}.png').convert('RGB') for i in range(24)]
        # Tight ROIs contain only the actual animal at fixed camera/time, not the
        # hero or animated environment. This rejects a frozen replacement sheet.
        motion = []
        for rect in [(555, 290, 755, 425), (770, 275, 970, 425)]:
            first = frames[0].crop(rect)
            motion.append(max(sum(ImageChops.difference(first, f.crop(rect)).convert('L').histogram()[8:])
                              for f in frames[1:]))
        if min(motion) < 20:
            raise RuntimeError(f'Missing {gait} articulation: {motion}')
        changes[gait] = motion
        frames[0].save(OUTPUT / f'wildlife-{gait}.gif', save_all=True,
                       append_images=frames[1:], duration=80, loop=0, optimize=True, disposal=2)
        for image in frames:
            image.close()
    report.update(passed=True, images=77, directional_views=4,
                  fixed_camera_articulation_changed_pixels=changes,
                  note='Fixed-pose contact closeups; genuine moving gameplay remains in lantern-motion.')
    result_path.write_text(json.dumps(report, indent=2) + '\n')
    print('LANTERN_CONTACT_PASS', changes, flush=True)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
