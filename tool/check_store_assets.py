#!/usr/bin/env python3
"""Check store-facing image sizes, required metadata and forbidden branding."""
from html.parser import HTMLParser
from pathlib import Path
import sys

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
errors: list[str] = []


def image(path: str, size: tuple[int, int], opaque: bool = True) -> None:
    p = ROOT / path
    if not p.is_file():
        errors.append(f"missing image: {path}")
        return
    with Image.open(p) as im:
        if im.size != size:
            errors.append(f"{path}: expected {size}, got {im.size}")
        if opaque and im.convert("RGBA").getchannel("A").getextrema() != (255, 255):
            errors.append(f"{path}: alpha channel is not fully opaque")


def exists(path: str) -> None:
    if not (ROOT / path).is_file():
        errors.append(f"missing file: {path}")


# Apple: current App Store marketing sizes.
image("store/apple/screenshots/6.9/01-hero.png", (1320, 2868))
image("store/apple/screenshots/6.9/02-twist.png", (1320, 2868))
image("store/apple/screenshots/6.9/03-poke.png", (1320, 2868))
image("store/apple/screenshots/6.9/04-drop.png", (1320, 2868))
image("store/apple/screenshots/6.9/05-4x4.png", (1320, 2868))
image("store/apple/screenshots/6.9/06-extra-types.png", (1320, 2868))
image("store/apple/screenshots/6.5/01-hero.png", (1242, 2688))
image("store/apple/screenshots/6.5/02-twist.png", (1242, 2688))
image("store/apple/screenshots/ipad-13/01-hero.png", (2064, 2752))
image("store/apple/icon-1024.png", (1024, 1024))

# Google Play.
image("store/google/icon-512.png", (512, 512))
image("store/google/feature-graphic-1024x500.png", (1024, 500))
image("store/google/screenshots/phone/01-hero.png", (1080, 1920))
image("store/google/screenshots/phone/02-4x4.png", (1080, 1920))
image("store/google/screenshots/tablet-7/01-tablet.png", (1440, 2560))

# AppGallery: capture is from the OpenHarmony emulator, not upscaled.
for name in ("01-hero.jpg", "02-twist.jpg", "03-controls.jpg"):
    exists(f"store/huawei/screenshots/phone/{name}")

for path in (
    "store/apple/metadata/en-US/name.txt",
    "store/apple/metadata/en-US/description.txt",
    "store/apple/metadata/en-US/keywords.txt",
    "store/apple/review-notes.txt",
    "store/google/metadata/en-US/title.txt",
    "store/google/metadata/en-US/short_description.txt",
    "store/google/metadata/en-US/full_description.txt",
    "store/huawei/listing-en.md",
    "store/huawei/iap-product.md",
    "store/site/jellycube3d/index.html",
    "store/site/jellycube3d/privacy/index.html",
    "store/site/jellycube3d/support/index.html",
    "store/site/jellycube3d/terms/index.html",
    "docs/PRIVACY.md",
    "docs/TERMS.md",
    "docs/SUPPORT.md",
):
    exists(path)

# Character limits that stores enforce at submission time.
limits = {
    "store/apple/metadata/en-US/name.txt": 30,
    "store/apple/metadata/en-US/subtitle.txt": 30,
    "store/apple/metadata/en-US/promotional_text.txt": 170,
    "store/apple/metadata/en-US/keywords.txt": 100,
    "store/apple/metadata/en-US/description.txt": 4000,
    "store/google/metadata/en-US/title.txt": 30,
    "store/google/metadata/en-US/short_description.txt": 80,
    "store/google/metadata/en-US/full_description.txt": 4000,
}
for path, limit in limits.items():
    p = ROOT / path
    if p.is_file() and len(p.read_text().strip()) > limit:
        errors.append(f"{path}: {len(p.read_text().strip())} chars > {limit}")

for path in (
    "store/apple/metadata/en-US/privacy_url.txt",
    "store/apple/metadata/en-US/support_url.txt",
    "store/apple/metadata/en-US/marketing_url.txt",
):
    p = ROOT / path
    if p.is_file() and not p.read_text().strip().startswith("https://"):
        errors.append(f"{path}: must be an https:// URL")

class LocalLinks(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.hrefs: list[str] = []

    def handle_starttag(self, tag, attrs):
        if tag == "a":
            for key, value in attrs:
                if key == "href" and value:
                    self.hrefs.append(value)

for page in (ROOT / "store/site/jellycube3d").rglob("*.html"):
    parser = LocalLinks()
    parser.feed(page.read_text())
    for href in parser.hrefs:
        if href.startswith(("http://", "https://", "mailto:", "#")):
            continue
        target = (page.parent / href).resolve()
        if not target.exists():
            errors.append(f"{page.relative_to(ROOT)}: broken local link {href}")

for md in (ROOT / "store").rglob("*.md"):
    text = md.read_text(errors="ignore")
    for line in text.splitlines():
        if "Rubik" in line and "old" not in line.lower() and "prohibit" not in line.lower():
            errors.append(f"forbidden old brand in {md.relative_to(ROOT)}: {line.strip()[:80]}")

if errors:
    print("STORE ASSET CHECK FAILED")
    for error in errors:
        print(f" - {error}")
    sys.exit(1)

print("STORE ASSET CHECK PASSED")
