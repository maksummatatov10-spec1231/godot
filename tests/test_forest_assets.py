"""The distributable forest game must be self-contained, not tied to the library mount."""
import json
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1] / 'forest_game'


class ForestAssetTests(unittest.TestCase):
    def test_every_gltf_buffer_and_texture_exists(self):
        for path in ROOT.glob('assets/**/*.gltf'):
            data = json.loads(path.read_text())
            for entry in data.get('buffers', []) + data.get('images', []):
                if 'uri' in entry:
                    with self.subTest(model=path.name, uri=entry['uri']):
                        self.assertTrue((path.parent / entry['uri']).is_file())
            for entry in data.get('buffers', []):
                self.assertEqual((path.parent / entry['uri']).stat().st_size, entry['byteLength'])

    def test_required_animation_channels_target_existing_same_rig_nodes(self):
        data = json.loads((ROOT / 'assets/hero/warden.gltf').read_text())
        names = {anim['name'] for anim in data['animations']}
        self.assertTrue({'Walk_Loop', 'Sword_Idle', 'Jump_Start', 'Jump_Loop', 'Jump_Land',
                         'Sword_Regular_A', 'Sword_Regular_B', 'Sword_Regular_C',
                         'Spell_Simple_Shoot'}.issubset(names))
        for anim in data['animations']:
            self.assertGreater(len(anim['channels']), 100)
            for channel in anim['channels']:
                self.assertLess(channel['target']['node'], len(data['nodes']))

    def test_serialized_resources_have_no_missing_author_project_dependencies(self):
        for path in ROOT.rglob('*'):
            if '.godot' in path.parts or path.suffix not in {'.tscn', '.tres', '.gdshader'}:
                continue
            for reference in re.findall(r'res://[^"\s)]+', path.read_text()):
                with self.subTest(file=path.name, reference=reference):
                    self.assertTrue((ROOT / reference[6:]).is_file())

    def test_licenses_retained_and_main_scene_present(self):
        licenses = json.loads((ROOT / 'ASSET_LICENSES.json').read_text())
        self.assertGreaterEqual(len(licenses), 5)
        self.assertTrue(all('CC0' in entry['text'] for entry in licenses if 'license' in Path(entry['path']).name.lower()))
        self.assertIn('run/main_scene="res://world.tscn"', (ROOT / 'project.godot').read_text())
        self.assertTrue((ROOT / 'world.tscn').exists())


if __name__ == '__main__':
    unittest.main()
