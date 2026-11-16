"""Every required evidence stage must pass, including external GDScript parsing."""
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from capture_lantern import steps_passed


class LanternCaptureGate(unittest.TestCase):
    def stages(self):
        return [{'name': name, 'passed': True} for name in
                ['import', 'drivers', 'gameplay', 'render', 'image-validation']]

    def test_all_required_stages_pass(self):
        self.assertTrue(steps_passed(self.stages()))

    def test_missing_driver_parse_is_rejected(self):
        self.assertFalse(steps_passed([s for s in self.stages() if s['name'] != 'drivers']))

    def test_duplicate_cannot_replace_a_missing_stage(self):
        stages = self.stages()
        stages[1]['name'] = 'import'
        self.assertFalse(steps_passed(stages))

    def test_failed_render_cannot_be_masked(self):
        stages = self.stages()
        stages[3]['passed'] = False
        self.assertFalse(steps_passed(stages))
