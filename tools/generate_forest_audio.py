"""Original deterministic sound design, CC0; no downloaded music dependency."""
import math
from pathlib import Path
import random
import struct
import subprocess
import tempfile
import wave

import imageio_ffmpeg

ROOT = Path(__file__).resolve().parents[1] / 'forest_game/audio'
RATE = 22050


def save(name, samples):
    ROOT.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory() as directory:
        path = Path(directory) / 'sound.wav'
        with wave.open(str(path), 'wb') as output:
            output.setparams((1, 2, RATE, len(samples), 'NONE', 'not compressed'))
            output.writeframes(b''.join(struct.pack('<h', max(-32767, min(32767, int(x * 32767)))) for x in samples))
        subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(), '-v', 'error', '-y', '-i', str(path),
                        '-c:a', 'libvorbis', '-q:a', '4', str(ROOT / (name + '.ogg'))], check=True)


def main():
    rng = random.Random(739)
    ambient = []
    wind_stem, bird_stem = [], []
    low = 0.0
    birds = [(rng.uniform(1, 19), rng.uniform(1800, 3200)) for _ in range(15)]
    for i in range(RATE * 20):
        t = i / RATE
        low = low * 0.985 + rng.uniform(-1, 1) * 0.015
        value = low * (0.5 + 0.2 * math.sin(t * math.tau / 20))
        bird_value = 0.0
        for start, freq in birds:
            local = t - start
            if 0 < local < 0.23:
                env = math.sin(math.pi * local / 0.23) ** 2
                bird_value += math.sin(math.tau * (freq * local + 1200 * local * local)) * env * 0.065
        # Fade through the loop boundary; no click, both endpoints zero.
        fade = min(1, t / 0.3, (20 - t) / 0.3)
        wind_stem.append(value * fade)
        bird_stem.append(bird_value * fade)
        value = (value + bird_value) * fade
        ambient.append(value)
    save('forest-air', ambient)
    save('wind', wind_stem)
    save('birds', bird_stem)
    for name, duration in [('footstep', 0.16), ('sword', 0.42), ('arcane', 0.8)]:
        samples = []
        for i in range(int(RATE * duration)):
            t = i / RATE
            u = t / duration
            if name == 'footstep':
                value = (rng.uniform(-1, 1) * 0.15 + math.sin(t * math.tau * 90) * 0.22) * math.exp(-u * 10)
            elif name == 'sword':
                value = rng.uniform(-1, 1) * math.sin(math.pi * u) ** 3 * 0.25
            else:
                value = sum(math.sin(math.tau * (f * t + 100 * t * t)) for f in [330, 660, 990]) * math.sin(math.pi * u) ** 2 * 0.07
            samples.append(value)
        save(name, samples)


if __name__ == '__main__':
    main()
