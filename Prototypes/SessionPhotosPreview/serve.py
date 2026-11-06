"""Serve only the participant-photo mockup and its bundled assets on loopback."""

import argparse
import mimetypes
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[2]
PREVIEW = ROOT / "Prototypes/SessionPhotosPreview"
FILES = {
    "/": PREVIEW / "index.html",
    "/Prototypes/SessionPhotosPreview/": PREVIEW / "index.html",
    "/Prototypes/SessionPhotosPreview/index.html": PREVIEW / "index.html",
    "/Prototypes/SessionPhotosPreview/preview.css": PREVIEW / "preview.css",
    "/Prototypes/SessionPhotosPreview/preview.js": PREVIEW / "preview.js",
    "/styles.css": ROOT / "styles.css",
    "/assets/brand/logo-mark.svg": ROOT / "assets/brand/logo-mark.svg",
}
for name in ["fonts.css", "colors.css", "typography.css", "spacing.css", "base.css"]:
    FILES[f"/design-system/tokens/{name}"] = ROOT / "design-system/tokens" / name
for name in ["BricolageGrotesque.woff2", "Archivo-normal.woff2", "Archivo-italic.woff2", "JetBrainsMono-normal.woff2"]:
    FILES[f"/assets/fonts/{name}"] = ROOT / "assets/fonts" / name
for name in ["group-class", "roll-gi", "coach-help"]:
    FILES[f"/assets/photos/{name}.jpg"] = ROOT / "assets/photos" / f"{name}.jpg"
for name in ["chevron-left", "chevron-right", "notebook-pen", "clock", "map-pin", "lock", "camera", "repeat-2", "check", "user", "x", "ellipsis", "trash-2"]:
    FILES[f"/assets/icons/{name}.svg"] = ROOT / "assets/icons" / f"{name}.svg"


class PreviewHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.serve(send_body=True)

    def do_HEAD(self):
        self.serve(send_body=False)

    def serve(self, send_body):
        request = urlsplit(self.path)
        if request.path == "/":
            self.send_response(302)
            self.send_header("Location", "/Prototypes/SessionPhotosPreview/" + (f"?{request.query}" if request.query else ""))
            self.end_headers()
            return
        path = FILES.get(request.path)
        if path is None or not path.is_file():
            self.send_error(404)
            return
        content = path.read_bytes()
        self.send_response(200)
        self.send_header("Content-Type", mimetypes.guess_type(str(path))[0] or "application/octet-stream")
        self.send_header("Content-Length", str(len(content)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.end_headers()
        if send_body:
            self.wfile.write(content)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=4177)
    args = parser.parse_args()
    with ThreadingHTTPServer(("127.0.0.1", args.port), PreviewHandler) as server:
        print(f"Participant-photo mockup: http://127.0.0.1:{args.port}/Prototypes/SessionPhotosPreview/", flush=True)
        server.serve_forever()
