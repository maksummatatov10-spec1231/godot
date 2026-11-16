"""Measure identical 0.1.4/current scenes and validate culling against full-world rendering.

Normal mode needs Xvfb/Mesa. CPU-only mode works headless and makes no GPU/FPS claim.
"""
import argparse
import io
import json
import os
from pathlib import Path
import subprocess
import tarfile

from PIL import Image, ImageChops

from capture_lantern import ROOT, GAME, game_digest

BASELINE = '15892813fe0437e4739049159ec854c2cd322b4a'
OUTPUT = ROOT / 'docs/evidence/lantern-performance'


def run(command, output, marker='', **variables):
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open('w') as log:
        result = subprocess.run(command, env=dict(os.environ, **variables), cwd=ROOT,
                                stdout=log, stderr=subprocess.STDOUT, timeout=300)
    text = output.read_text()
    if result.returncode or 'ERROR:' in text or 'leaked' in text or marker not in text:
        raise RuntimeError(f'{output}: exit {result.returncode}\n{text[-6000:]}')


def changed_pixels(a, b, threshold=12):
    with Image.open(a) as first, Image.open(b) as second:
        if first.size != second.size:
            raise RuntimeError('Mismatched locality images')
        diff = ImageChops.difference(first.convert('RGB'), second.convert('RGB'))
        red, green, blue = diff.split()
        maximum = ImageChops.lighter(ImageChops.lighter(red, green), blue)
        return sum(maximum.histogram()[threshold + 1:])


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--cpu-only', action='store_true')
    args = parser.parse_args()
    engine = os.environ.get('GODOT4_BIN', str(ROOT / '.tools/godot/Godot_v4.7.2-stable_linux.x86_64'))
    baseline_dir = ROOT / '.tools/lantern/performance-baseline'
    baseline_dir.mkdir(parents=True, exist_ok=True)
    archive = subprocess.check_output(['git', 'archive', BASELINE, 'lantern_game'], cwd=ROOT)
    with tarfile.open(fileobj=io.BytesIO(archive)) as bundle:
        # Trusted local git archive; validate paths/types also on Python 3.10,
        # which has no tarfile extraction filters.
        for member in bundle.getmembers():
            if not (member.isfile() or member.isdir()):
                raise RuntimeError('Unexpected baseline archive member')
            (baseline_dir / member.name).resolve().relative_to(baseline_dir.resolve())
        bundle.extractall(baseline_dir)
    report = {'passed': False, 'baseline_commit': BASELINE, 'game_sha256': game_digest(),
              'physical_gpu_benchmark': False, 'cpu_only': args.cpu_only,
              'method': '20 warm-ups + 120 samples/view; identical scene/camera/player animation',
              'renderer': 'headless CPU only' if args.cpu_only else 'Compatibility / Mesa software'}
    result_path = OUTPUT / 'result.json'
    result_path.write_text(json.dumps(report, indent=2) + '\n')
    games = [('before', baseline_dir / 'lantern_game'), ('after', GAME)]
    for label, project in games:
        run([engine, '--headless', '--path', str(project), '--editor', '--import'],
            OUTPUT / f'{label}-import.log')
        for rendered in ([False] if args.cpu_only else [False, True]):
            name = label + ('-rendered' if rendered else '-cpu')
            directory = OUTPUT / name
            command = [engine, '--path', str(project), '--audio-driver', 'Dummy',
                       '--script', str(ROOT / 'tools/lantern_benchmark.gd')]
            if rendered:
                command = ['xvfb-run', '-a', '-s', '-screen 0 1280x720x24', *command,
                           '--resolution', '1280x720', '--disable-vsync']
            else:
                command += ['--headless']
            run(command, directory / 'benchmark.log', 'LANTERN_BENCH_OK',
                BENCH_DIR=str(directory), BENCH_RENDERED='1' if rendered else '0')
            report[name] = json.loads((directory / 'benchmark.json').read_text())
    ratios = {}
    for before, after in zip(report['before-cpu']['views'], report['after-cpu']['views']):
        assert before['view'] == after['view']
        ratio = before['shadow_cpu_ms_median'] / after['shadow_cpu_ms_median']
        if ratio < 2:
            raise RuntimeError(f'Shadow CPU regression in {after["view"]}: speedup {ratio}')
        if after['shadow_work']['depth_pixels'] >= 1536 * 1152:
            raise RuntimeError('Light maps are not camera-local')
        ratios[after['view']] = round(ratio, 2)
    report['shadow_cpu_speedup'] = ratios
    if not args.cpu_only:
        directory = OUTPUT / 'locality'
        run(['xvfb-run', '-a', '-s', '-screen 0 1280x720x24', engine,
             '--path', str(GAME), '--audio-driver', 'Dummy', '--fixed-fps', '30',
             '--resolution', '1280x720', '--script', str(ROOT / 'tools/lantern_locality.gd')],
            directory / 'render.log', 'LANTERN_LOCALITY_OK 6', LOCALITY_DIR=str(directory))
        pairs = json.loads((directory / 'capture.json').read_text())['pairs']
        differences = {name: changed_pixels(directory / f'{name}-local.png',
                                           directory / f'{name}-reference.png') for name in pairs}
        # Pixel-centred lookup must be independent of the crop. No missing
        # shadow pixel is tolerated; threshold 12 ignores tiny sunlight rounding.
        if len(differences) != 6 or max(differences.values()) != 0:
            raise RuntimeError(f'Camera culling changes visible output: {differences}')
        report['local_vs_full_world_changed_pixels_over_12'] = differences
    if report['game_sha256'] != game_digest():
        raise RuntimeError('Game changed during performance capture')
    report['passed'] = True
    result_path.write_text(json.dumps(report, indent=2) + '\n')
    print('LANTERN_PERFORMANCE_OK', ratios, flush=True)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
