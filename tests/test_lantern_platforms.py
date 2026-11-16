import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest
import zipfile
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from package_lantern_platforms import build_platform_archive


class PlatformPackaging(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.base = self.root / 'source.zip'
        with zipfile.ZipFile(self.base, 'w') as z:
            z.writestr('LanternValley/project.godot', '[application]\nconfig/version="0.4.0"\n')
            z.writestr('LanternValley/scripts/game.gd', 'extends Node2D\n')

    def test_two_platforms_share_game_not_copied_forks(self):
        for profile in ('pc', 'android'):
            output = self.root / (profile + '.zip')
            row = build_platform_archive(self.base, output, profile, 'verified-game')
            with zipfile.ZipFile(output) as z:
                self.assertEqual(z.read('LanternValley/scripts/game.gd'), b'extends Node2D\n')
                self.assertEqual(json.loads(z.read('LanternValley/PLATFORM.json'))['profile'], profile)
                self.assertEqual('LanternValley/override.cfg' in z.namelist(), profile == 'android')
            self.assertEqual(row['sha256'], hashlib.sha256(output.read_bytes()).hexdigest())

    def test_profiles_have_reproducible_zip_metadata(self):
        first, second = self.root / 'first.zip', self.root / 'second.zip'
        build_platform_archive(self.base, first, 'android', 'hash')
        build_platform_archive(self.base, second, 'android', 'hash')
        self.assertEqual(first.read_bytes(), second.read_bytes())

    def test_signing_keys_cannot_leak_into_source_zip(self):
        with zipfile.ZipFile(self.base, 'a') as z:
            z.writestr('LanternValley/private.keystore', 'not-a-real-key')
        with self.assertRaises(RuntimeError):
            build_platform_archive(self.base, self.root / 'bad.zip', 'pc', 'hash')

    def test_unknown_platform_rejected(self):
        with self.assertRaises(ValueError):
            build_platform_archive(self.base, self.root / 'bad.zip', 'ios', 'hash')
