"""A PNG alone must never turn a crashing or fallback editor into a passing test."""
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import capture_editor


class EditorCaptureTests(unittest.TestCase):
    def run_capture(self, log_text):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / 'editor.png'
            image = Image.new('RGB', (1280, 800), '#222222')
            ImageDraw.Draw(image).rectangle((200, 100, 900, 700), fill='#447799')
            process = Mock(pid=12345)
            process.poll.return_value = None
            process.wait.side_effect = [subprocess.TimeoutExpired('editor', 1), -15]

            def launch(*args, **kwargs):
                kwargs['stdout'].write(log_text)
                kwargs['stdout'].flush()
                return process

            with patch('sys.argv', ['capture_editor.py', '--output', str(target)]), \
                    patch.dict(capture_editor.os.environ, {'DISPLAY': ':99'}), \
                    patch.object(capture_editor, 'resolve_engine', return_value='fake-godot'), \
                    patch.object(capture_editor.subprocess, 'Popen', side_effect=launch), \
                    patch.object(capture_editor.ImageGrab, 'grab', return_value=image), \
                    patch.object(capture_editor.os, 'killpg'):
                capture_editor.main()
                self.assertTrue(target.is_file())

    def test_actual_forward_plus_editor_frame(self):
        self.run_capture('Vulkan 1.4 - Forward+ - Using Device #0: llvmpipe\n')

    def test_error_in_engine_log_rejects_even_valid_png(self):
        for error in ['ERROR: shader failed', 'SCRIPT ERROR: broken', 'Program crashed']:
            with self.subTest(error=error), self.assertRaisesRegex(RuntimeError, 'error/crash'):
                self.run_capture('Forward+ - Using Device #0\n' + error)

    def test_opengl_fallback_cannot_claim_forward_plus(self):
        with self.assertRaisesRegex(RuntimeError, 'did not confirm Forward'):
            self.run_capture('OpenGL - Compatibility - Using Device #0\n')


if __name__ == '__main__':
    unittest.main()
