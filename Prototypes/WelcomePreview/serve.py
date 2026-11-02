"""Serve only the welcome preview's bundled assets on loopback, never the checkout."""
import argparse
import mimetypes
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[2]
PREVIEW = ROOT / "Prototypes/WelcomePreview/index.html"
FILES = {"/": PREVIEW, "/Prototypes/WelcomePreview/": PREVIEW,
         "/Prototypes/WelcomePreview/index.html": PREVIEW, "/styles.css": ROOT / "styles.css"}
for filename in ["fonts.css", "colors.css", "typography.css", "spacing.css", "base.css"]:
    FILES[f"/design-system/tokens/{filename}"] = ROOT / "design-system/tokens" / filename
for filename in ["BricolageGrotesque.woff2", "Archivo-normal.woff2", "Archivo-italic.woff2", "JetBrainsMono-normal.woff2"]:
    FILES[f"/assets/fonts/{filename}"] = ROOT / "assets/fonts" / filename
for filename in ["roll-gi-2.jpg", "coach-help.jpg", "group-class.jpg", "portrait-gi.jpg"]:
    FILES[f"/assets/photos/{filename}"] = ROOT / "assets/photos" / filename
GOOGLE = "Prototypes/MatMind/Resources/Assets.xcassets/GoogleSignIn.imageset/google.svg"
FILES[f"/{GOOGLE}"] = ROOT / GOOGLE


class PreviewHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.serve(send_body=True)

    def do_HEAD(self):
        self.serve(send_body=False)

    def serve(self, send_body):
        path = FILES.get(urlsplit(self.path).path)
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
    parser.add_argument("--port", type=int, default=4174)
    args = parser.parse_args()
    with ThreadingHTTPServer(("127.0.0.1", args.port), PreviewHandler) as server:
        print(f"Welcome preview listening on loopback port {args.port}", flush=True)
        server.serve_forever()
