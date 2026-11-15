"""Static policy contracts supplement, but never stand in for, real GPU tests."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]


class RendererPolicyTests(unittest.TestCase):
    def test_forward_plus_and_no_silent_gl_fallback(self):
        text = (ROOT / 'godot/project.godot').read_text()
        self.assertIn('renderer/rendering_method="forward_plus"', text)
        self.assertIn('rendering_device/fallback_to_opengl3=false', text)
        for name in ['terrain_3d', 'SunshineClouds2', 'assets2godot']:
            self.assertIn(f'res://addons/{name}/plugin.cfg', text)
            self.assertTrue((ROOT / 'godot/addons' / name / 'plugin.cfg').is_file())

    def test_cloud_budget_is_explicit(self):
        text = (ROOT / 'godot/resources/clouds_balanced.tres').read_text()
        self.assertIn('resolution_scale = 2', text)
        self.assertIn('max_step_count = 64.0', text)
        self.assertIn('max_lighting_steps = 8.0', text)
        for path in re.findall(r'path="res://([^"]+)"', text):
            self.assertTrue((ROOT / 'godot' / path).is_file(), path)

    def test_shader_includes_are_present(self):
        addon = ROOT / 'godot/addons/SunshineClouds2'
        for path in addon.rglob('*'):
            if path.suffix not in {'.glsl', '.comp', '.rast'}:
                continue
            for include in re.findall(r'#include\s+"([^"]+)"', path.read_text()):
                self.assertTrue((path.parent / include).is_file(), f'{path}: {include}')

    def test_noise_textures_keep_three_dimensional_imports(self):
        addon = ROOT / 'godot/addons/SunshineClouds2/NoiseTextures'
        for name in ['curl_noise_varied.tga', 'bluenoise_Dither.png']:
            text = (addon / (name + '.import')).read_text()
            self.assertIn('importer="3d_texture"', text)
            self.assertIn('type="CompressedTexture3D"', text)

    def test_visual_tool_defaults_to_forward_plus(self):
        text = (ROOT / 'tools/check.py').read_text()
        self.assertIn('default="forward_plus"', text)
        self.assertIn('"--rendering-method", args.renderer', text)
        self.assertIn('explicit --renderer gl_compatibility', text)

    def test_offline_client_cannot_restart_from_settings_signal(self):
        text = (ROOT / 'godot/addons/assets2godot/plugin.gd').read_text()
        setter = text.split('func set_client_enabled(enabled: bool) -> void:', 1)[1]
        setter = setter.split('\n\nfunc ', 1)[0]
        self.assertIn('assets2godot/offline_mode', setter)
        self.assertLess(setter.index('enabled = false'), setter.index('connection.start()'))


if __name__ == '__main__':
    unittest.main()
