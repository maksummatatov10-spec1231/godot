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

    def test_whole_route_network_and_clear_tree_trunks(self):
        paths={tuple(p) for p in self.map['paths']}
        reached={next(iter(paths))}
        todo=list(reached)
        while todo:
            x,y=todo.pop()
            for p in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)]:
                if p in paths and p not in reached:
                    reached.add(p);todo.append(p)
        self.assertEqual(reached, paths, 'No disconnected fragments of road')
        for solid in self.map['solids']:
            if solid['kind']!='tree':continue
            x,y,w,h=solid['rect']
            self.assertFalse(any(x<xx*16+16 and x+w>xx*16 and y<yy*16+16 and y+h>yy*16
                                 for xx,yy in paths), solid)
        for x,y in self.map['doors']:
            self.assertIn((x//16,y//16),paths)
            self.assertIn((x//16,y//16+1),paths)

    def test_single_tree_crops_not_clusters_and_exact_sort_bases(self):
        nature=Image.open(GAME/'assets/ninja/Backgrounds/Tilesets/TilesetNature.png').convert('RGBA')
        for i,(x,y,w,h) in enumerate([(3,18,3,3),(2,0,2,2),(0,0,2,2),(0,18,3,3)]):
            source=nature.crop((x*16,y*16,(x+w)*16,(y+h)*16))
            actual=Image.open(GAME/f'assets/world/tree_{i}.png').convert('RGBA')
            self.assertEqual(actual.tobytes(),source.tobytes())
            self.assertEqual(actual.size,source.size)
        for item in self.map['objects']:
            self.assertGreater(item['sort_y'],0)
            self.assertLessEqual(item['sort_y'],item['size'][1])
            if item['art'].startswith('house'):
                self.assertEqual(item['sort_y'],72)
                self.assertEqual(item['size'][1],72)
        self.assertEqual(len([o for o in self.map['objects'] if o['sway']]),
                         len([s for s in self.map['solids'] if s['kind']=='tree']))

    def test_no_shadowing_warning_or_implicit_pcm_integer_division(self):
        code=(GAME/'scripts/game.gd').read_text()
        self.assertNotIn('var material :=',code)
        self.assertNotIn('samples.size() / 2',code)
        self.assertIn('gdscript/warnings/shadowed_variable_base_class=2',
                      (GAME/'project.godot').read_text())

    def test_road_centre_uses_dirt_centre_not_sand_or_grass_edge(self):
        ground=Image.open(GAME/'assets/world/ground.png').convert('RGBA')
        source=Image.open(GAME/'assets/ninja/Backgrounds/Tilesets/TilesetFloor.png').convert('RGBA')
        self.assertEqual(ground.crop((48*16,50*16,49*16,51*16)).tobytes(),
                         source.crop((16,128,32,144)).tobytes())

    def test_no_crowns_swallow_authored_buildings_or_props(self):
        trees=[o for o in self.map['objects'] if o['sway']]
        props=[o for o in self.map['objects'] if not o['sway']]
        for tree in trees:
            x,y=tree['position'];w,h=tree['size']
            for prop in props:
                a,b=prop['position'];c,d=prop['size']
                self.assertFalse(x<a+c and x+w>a and y<b+d and y+h>b,(tree,prop))
        for solid in self.map['solids']:
            if solid['kind']!='fence':continue
            x,y,w,h=solid['rect']
            self.assertGreaterEqual(x,1045)
            self.assertLessEqual(x+w,1277)
            self.assertGreaterEqual(y,836)
            self.assertLessEqual(y+h,988)

    def test_market_counters_do_not_block_painted_streets(self):
        for solid in self.map['solids']:
            if solid['kind']!='stall':continue
            x,y,w,h=solid['rect']
            self.assertFalse(any(x<a*16+16 and x+w>a*16 and y<b*16+16 and y+h>b*16
                                 for a,b in self.map['paths']),solid)

    def test_live_shadows_replace_baked_runtime_layer(self):
        code=(GAME/'scripts/game.gd').read_text()
        self.assertNotIn('sun_shadows.png',code)
        shadows=(GAME/'scripts/shadows.gd').read_text()
        self.assertIn('source.global_transform',shadows)
        self.assertIn('silhouette.region_rect = source.region_rect',shadows)
        self.assertIn('silhouette.visible = source.is_visible_in_tree()',shadows)
        self.assertIn('shadows.register(actor.tool, actor, true)',code)
        self.assertNotIn('sun_shadows.png',(ROOT/'tools/build_lantern_map.py').read_text())

    def test_plants_are_live_casters_not_baked_into_soil(self):
        kinds=[a['kind'] for a in self.map['animations']]
        self.assertEqual(kinds.count('seedling'),40)
        self.assertEqual(kinds.count('flowerbed'),24)
        for name in ['seedling','flowerbed']:
            with Image.open(GAME/'assets/world'/f'{name}.png') as image:
                self.assertIsNotNone(image.getbbox())

    def test_foliage_and_shadow_use_identical_wind(self):
        foliage=(GAME/'scripts/foliage.gdshader').read_text()
        shadow=(GAME/'scripts/cast_shadow.gdshader').read_text()
        # Changing source crown movement without its shadow is a regression.
        for expression in ['clamp(-VERTEX.y / max(crown_height, 1.0), 0.0, 1.0)',
                           'sin(wind_time * 1.7 + phase) * 1.25',
                           'sin(wind_time * 0.63 + phase * 0.7) * 0.65',
                           'breeze * height_weight * height_weight']:
            self.assertIn(expression,foliage)
            self.assertIn(expression,shadow)

    def test_no_mix_with_3d_project(self):
        self.assertNotIn('forest_game',(GAME/'project.godot').read_text())
        self.assertEqual(self.map['spawn'],[776,658])


if __name__=='__main__':
    unittest.main()
