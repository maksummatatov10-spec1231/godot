"""Acceptance driver must never turn a logd transport error into a passing test."""
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
import smoke_lantern_android as driver


class AndroidAcceptanceDriver(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.output = Path(temporary.name)
        patcher = patch.object(driver, 'OUT', self.output)
        patcher.start()
        self.addCleanup(patcher.stop)

    def test_failed_partial_logcat_cannot_supply_pass_marker(self):
        result = subprocess.CompletedProcess([], 255, 'LANTERN_ANDROID_SMOKE_OK', 'unexpected EOF')
        with patch.object(driver.subprocess, 'run', return_value=result):
            self.assertEqual(driver.logs(), '')
        text = (self.output / 'android-adb.log').read_text()
        self.assertIn('255', text)
        self.assertIn('unexpected EOF', text)

    def test_transient_dump_retries_until_successful_marker(self):
        with patch.object(driver, 'logs', side_effect=['', 'LANTERN_ANDROID_SMOKE_OK']), \
             patch.object(driver.time, 'sleep'):
            self.assertEqual(driver.wait_for('LANTERN_ANDROID_SMOKE_OK'), 'LANTERN_ANDROID_SMOKE_OK')

    def test_transport_failure_still_hits_deadline(self):
        with patch.object(driver, 'logs', return_value=''), \
             patch.object(driver.time, 'monotonic', side_effect=[0, 1, 101]), \
             patch.object(driver.time, 'sleep'):
            with self.assertRaisesRegex(RuntimeError, 'Android timeout'):
                driver.wait_for('LANTERN_ANDROID_SMOKE_OK')

    def test_shader_error_rejected_even_with_success_marker(self):
        with patch.object(driver, 'logs', return_value='E/godot: shader error LANTERN_ANDROID_SMOKE_OK'):
            with self.assertRaisesRegex(RuntimeError, 'Android runtime failure'):
                driver.wait_for('LANTERN_ANDROID_SMOKE_OK')
