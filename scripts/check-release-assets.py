#!/usr/bin/env python3
"""Check the built Release app, so excluded preview assets cannot silently return."""
import json
from pathlib import Path
import subprocess
import sys

app = Path(sys.argv[1])
preview_photos = Path(__file__).resolve().parents[1] / "Prototypes/MatMind/PreviewAssets.xcassets/Photos"
samples = {path.stem for path in preview_photos.glob("*.imageset")}
assert samples, "Preview photo inventory is missing"
catalog = app / "Assets.car"
assert catalog.is_file(), f"Compiled asset catalog is missing: {catalog}"
assets = json.loads(subprocess.check_output(["xcrun", "assetutil", "--info", str(catalog)], text=True))
names = {asset.get("Name") for asset in assets}
leaked = samples & names
assert not leaked, f"Sample photos are present in the Release app: {sorted(leaked)}"
loose_photos = {path.stem for path in app.rglob("*.jpg")}
assert not samples & loose_photos, "Sample JPEGs were copied directly into the Release app"
print(f"Verified Release app excludes all {len(samples)} sample photos")
