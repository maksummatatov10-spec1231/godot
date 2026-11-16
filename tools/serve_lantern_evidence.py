"""Serve the screenshot gallery with sibling PNG/GIF directories available."""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


class Gallery(SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/':
            self.send_response(302)
            self.send_header('Location', '/lantern-audit/')
            self.end_headers()
            return
        super().do_GET()


if __name__ == '__main__':
    root = Path(__file__).resolve().parents[1] / 'docs/evidence'
    handler = partial(Gallery, directory=str(root))
    print('Screenshot gallery on http://0.0.0.0:8081', flush=True)
    ThreadingHTTPServer(('0.0.0.0', 8081), handler).serve_forever()
