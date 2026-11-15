"""Source licensing, pixel-derived shoreline and art/physics placement regression checks."""
import hashlib
import json
from pathlib import Path
import unittest

from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
GAME=ROOT/'lantern_game'


class LanternAssets(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.map=json.loads((GAME/'assets/world/map.json').read_text())

    def test_selected_art_matches_verified_cc0_archive(self):
        intake=json.loads((GAME/'assets/intake.json').read_text())
        self.assertEqual(intake['source_md5'],'cd56f13d4ceb33f0e90a1447a86ad8c5')
        for file in intake['files']:
            content=(GAME/'assets/ninja'/file['path']).read_bytes()
            self.assertEqual(hashlib.sha256(content).hexdigest(),file['sha256'])
        self.assertIn('CC0 1.0 Universal',(GAME/'assets/ninja/LICENSE.txt').read_text())

    def test_all_placed_objects_have_matching_art_size(self):
        for obj in self.map['objects']:
            with Image.open(GAME/'assets/world'/obj['art']) as image:
                self.assertEqual(list(image.size),obj['size'])
        self.assertEqual(sum(s['kind']=='house' for s in self.map['solids']),12)

    def test_water_solids_match_cyan_art_not_grass(self):
        with Image.open(GAME/'assets/world/ground.png') as image:
            for item in self.map['solids']:
                if item['kind']!='water':continue
                x,y,w,h=item['rect']
                for yy in range(y,y+h):
                    for xx in range(x,x+w):
                        r,g,b,*_=image.getpixel((xx,yy))
                        self.assertTrue(b>130 and g>145 and r<155,(xx,yy))

    def test_fences_follow_visible_rails(self):
        for art in ['fence_h.png','fence_v.png']:
            with Image.open(GAME/'assets/world'/art) as image:
                self.assertIsNotNone(image.getbbox())
        fences=[s['rect'] for s in self.map['solids'] if s['kind']=='fence']
        self.assertGreater(len(fences),25)
        # Gate: an actual 48px gap in the north rail, not invisible geometry.
        for x,y,w,h in fences:
            self.assertFalse(x<1168 and x+w>1120 and y<844 and y+h>836)

    def test_directional_hero_and_equipment_dimensions(self):
        with Image.open(GAME/'assets/ninja/Actor/CharacterAnimated/NinjaGreen/SpriteSheet.png') as im:
            self.assertEqual(im.size,(256,544))
        for name in ['Katana','Axe','Pickaxe','Net','Hammer']:
            with Image.open(GAME/f'assets/ninja/Actor/CharacterAnimated/Weapon/{name}.png') as im:
                self.assertEqual(im.size,(256,256))
        for name in ['fox','rabbit']:
            with Image.open(GAME/f'assets/world/{name}.png') as im:
                self.assertEqual(im.size,(64,64))

    def test_no_mix_with_3d_project(self):
        self.assertNotIn('forest_game',(GAME/'project.godot').read_text())
        self.assertEqual(self.map['spawn'],[776,658])


if __name__=='__main__':
    unittest.main()
