#!/usr/bin/env python3
"""Procedurally generate Jelly Cube 3D platform icons, launch art and store art.

This is a build-time art tool, not a runtime dependency. Requires Pillow.
No external image inputs are used.
"""
from __future__ import annotations

import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageOps, ImageFont

ROOT = Path(__file__).resolve().parent.parent
S = 2048
BRAND_DIR = ROOT / "branding"
BRAND_DIR.mkdir(exist_ok=True)

INK = (42, 33, 55)
BERRY = (138, 62, 96)
PLUM = (76, 45, 75)
LILAC_TOP = (238, 229, 247)
LILAC_BOTTOM = (205, 190, 225)
CREAM = (255, 248, 234)
BLUSH = (246, 221, 232)
LIME_LIGHT = (190, 246, 124)
LIME = (119, 216, 60)
LIME_DEEP = (55, 139, 29)
CHERRY_LIGHT = (255, 118, 138)
CHERRY = (213, 31, 61)
CHERRY_DEEP = (142, 8, 33)
COCONUT_LIGHT = (255, 255, 252)
COCONUT = (255, 249, 236)
COCONUT_DEEP = (240, 220, 184)


def lerp(a, b, t):
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def vertical_gradient(size, top, bottom):
    w, h = size
    strip = Image.new("RGB", (1, 256))
    px = strip.load()
    for y in range(256):
        px[0, y] = lerp(top, bottom, y / 255)
    return strip.resize((w, h), Image.Resampling.BICUBIC)


def diagonal_gradient(size, start, end):
    w, h = size
    small = vertical_gradient((1, 256), start, end)
    return small.resize((w, h), Image.Resampling.BICUBIC)


def radial_glow(size, color, alpha=255):
    w, h = size
    g = Image.radial_gradient("L").resize((w, h), Image.Resampling.BICUBIC)
    g = ImageOps.invert(g)
    g = g.point(lambda v: int(v * alpha / 255))
    layer = Image.new("RGBA", (w, h), color + (0,))
    layer.putalpha(g)
    return layer


def rounded_mask(points, radius=26):
    mask = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(mask)
    # Build a slightly chamfered polygon, then blur the silhouette for a jelly edge.
    d.polygon(points, fill=255)
    return mask.filter(ImageFilter.GaussianBlur(radius)).point(lambda v: 255 if v > 150 else 0)


def paste_face(base, poly, top, bottom, mask_radius=16):
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).polygon(poly, fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(mask_radius)).point(lambda v: 255 if v > 140 else 0)
    xs = [p[0] for p in poly]
    ys = [p[1] for p in poly]
    bbox = (min(xs), min(ys), max(xs), max(ys))
    grad = diagonal_gradient((S, S), top, bottom)
    base.paste(grad, (0, 0), mask)


def _lerp_pt(a, b, t):
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)


def _face_pt(origin, uvec, vvec, u, v):
    return (
        origin[0] + uvec[0] * u + vvec[0] * v,
        origin[1] + uvec[1] * u + vvec[1] * v,
    )


def _tile_poly(origin, uvec, vvec, u, v, gap=0.022):
    # A small inset keeps the mitred jelly seams readable at icon sizes.
    u0, u1 = u + gap, u + 1 - gap
    v0, v1 = v + gap, v + 1 - gap
    pts = [
        _face_pt(origin, uvec, vvec, u0, v0),
        _face_pt(origin, uvec, vvec, u1, v0),
        _face_pt(origin, uvec, vvec, u1, v1),
        _face_pt(origin, uvec, vvec, u0, v1),
    ]
    # Cut each corner into a small octagon so the stickers read as jelly.
    cut = 0.10
    out = []
    for i, cur in enumerate(pts):
        prev = pts[i - 1]
        nxt = pts[(i + 1) % len(pts)]
        out.append((cur[0] + (prev[0] - cur[0]) * cut, cur[1] + (prev[1] - cur[1]) * cut))
        out.append((cur[0] + (nxt[0] - cur[0]) * cut, cur[1] + (nxt[1] - cur[1]) * cut))
    return out


def make_cube(size=2048, transparent=False, mono=False, cube_scale=1.0):
    # Coordinates for a chunky 3x3 jelly cube, centered.
    cx = size // 2
    scale = size / 2048.0 * cube_scale
    def p(x, y):
        return (int(cx + (x - 1024) * scale), int((y - 930) * scale + size * 0.47))

    apex = p(1024, 350)
    lu = p(360, 750)
    ru = p(1688, 750)
    mid = p(1024, 1150)
    lb = p(360, 1550)
    rb = p(1688, 1550)
    bottom = p(1024, 1950)

    top_origin = apex
    top_u = ((ru[0] - apex[0]) / 3, (ru[1] - apex[1]) / 3)
    top_v = ((lu[0] - apex[0]) / 3, (lu[1] - apex[1]) / 3)
    left_origin = lu
    left_u = ((mid[0] - lu[0]) / 3, (mid[1] - lu[1]) / 3)
    left_v = ((lb[0] - lu[0]) / 3, (lb[1] - lu[1]) / 3)
    right_origin = ru
    right_u = ((mid[0] - ru[0]) / 3, (mid[1] - ru[1]) / 3)
    right_v = ((rb[0] - ru[0]) / 3, (rb[1] - ru[1]) / 3)

    top_tiles = [
        [COCONUT, COCONUT, COCONUT],
        [COCONUT, COCONUT, COCONUT],
        [COCONUT, COCONUT, COCONUT],
    ]
    left_tiles = [
        [LIME, LIME, LIME],
        [LIME, LIME, LIME],
        [LIME, LIME, LIME],
    ]
    right_tiles = [
        [CHERRY, CHERRY, CHERRY],
        [CHERRY, CHERRY, CHERRY],
        [CHERRY, CHERRY, CHERRY],
    ]

    if transparent:
        canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    else:
        canvas = vertical_gradient((size, size), LILAC_TOP, LILAC_BOTTOM).convert("RGBA")
        canvas = Image.alpha_composite(canvas, radial_glow((size, size), CREAM, 150))
        blush = radial_glow((size // 2, size // 2), BLUSH, 170)
        canvas.alpha_composite(blush, (size // 3, size // 3))

    if not mono:
        shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        sd = ImageDraw.Draw(shadow)
        sd.ellipse(
            (int(cx - 650 * scale), int(size * 0.855), int(cx + 650 * scale), int(size * 0.895)),
            fill=(68, 38, 62, 76),
        )
        shadow = shadow.filter(ImageFilter.GaussianBlur(44 * scale))
        canvas = Image.alpha_composite(canvas, shadow)

    cube = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    dc = ImageDraw.Draw(cube)

    # Dark flavour seam visible in the gaps and around the silhouette.
    for poly in ([apex, ru, mid, lu], [lu, mid, bottom, lb], [ru, mid, bottom, rb]):
        dc.polygon(poly, fill=(255, 255, 255, 255) if mono else (250, 243, 250, 255))

    def draw_face(origin, uvec, vvec, tiles):
        for row in range(3):
            for col in range(3):
                poly = _tile_poly(origin, uvec, vvec, col, row)
                color = tiles[row][col]
                dc.polygon(poly, fill=color + (255,), outline=(255, 255, 255, 190), width=max(2, int(3 * scale)))
                # Top bevel and bottom shade.
                top_edge = [poly[0], poly[1]]
                dc.line(top_edge, fill=(255, 255, 255, 130), width=max(2, int(4 * scale)))
                bottom_edge = [poly[2], poly[3]]
                dc.line(bottom_edge, fill=(120, 86, 114, 34), width=max(1, int(2 * scale)))

    draw_face(top_origin, top_u, top_v, top_tiles)
    draw_face(left_origin, left_u, left_v, left_tiles)
    draw_face(right_origin, right_u, right_v, right_tiles)

    def shade_face(poly, color, max_alpha, invert=False):
        mask = Image.new("L", (size, size), 0)
        ImageDraw.Draw(mask).polygon(poly, fill=255)
        mask = mask.filter(ImageFilter.GaussianBlur(10 * scale))
        alpha = Image.linear_gradient("L").resize((size, size))
        if invert:
            alpha = ImageOps.invert(alpha)
        alpha = alpha.point(lambda v: int(v * max_alpha / 255))
        layer = Image.new("RGBA", (size, size), color + (0,))
        layer.putalpha(Image.composite(alpha, Image.new("L", (size, size), 0), mask))
        return layer

    # Volumetric shading: lit top, deeper lower faces.
    cube = Image.alpha_composite(cube, shade_face([lu, mid, bottom, lb], (61, 31, 70), 70))
    cube = Image.alpha_composite(cube, shade_face([ru, mid, bottom, rb], (61, 31, 70), 96))
    cube = Image.alpha_composite(cube, shade_face([apex, ru, mid, lu], (255, 255, 255), 44, invert=True))

    # Cross-face rim: crisp wet edges where the three faces meet.
    for a, b in [(apex, lu), (apex, ru), (lu, mid), (ru, mid), (mid, bottom), (lu, lb), (ru, rb), (lb, bottom), (rb, bottom)]:
        dc.line([a, b], fill=(255, 255, 255, 185), width=max(3, int(7 * scale)), joint="curve")

    # Soft rounded outer silhouette.
    cube_mask = Image.new("L", (size, size), 0)
    md = ImageDraw.Draw(cube_mask)
    for poly in ([apex, ru, mid, lu], [lu, mid, bottom, lb], [ru, mid, bottom, rb]):
        md.polygon(poly, fill=255)
    cube_mask = cube_mask.filter(ImageFilter.GaussianBlur(26 * scale)).point(lambda v: 255 if v > 145 else 0)
    cube.putalpha(Image.composite(cube.getchannel("A"), Image.new("L", (size, size), 0), cube_mask))
    canvas = Image.alpha_composite(canvas, cube)

    if not mono:
        gloss = Image.new("RGBA", (size, size), (255, 255, 255, 0))
        gd = ImageDraw.Draw(gloss)
        # Soft wet bloom on the lit top facet plus two crisp speculars.
        gd.ellipse((
            int(cx - 500 * scale), int(size * 0.305),
            int(cx + 160 * scale), int(size * 0.445),
        ), fill=(255, 255, 255, 94))
        gd.ellipse((
            int(cx - 500 * scale), int(size * 0.55),
            int(cx - 300 * scale), int(size * 0.67),
        ), fill=(255, 255, 255, 34))
        gd.ellipse((
            int(cx - 205 * scale), int(size * 0.348),
            int(cx - 170 * scale), int(size * 0.365),
        ), fill=(255, 255, 255, 245))
        gd.ellipse((
            int(cx - 512 * scale), int(size * 0.585),
            int(cx - 490 * scale), int(size * 0.598),
        ), fill=(255, 255, 255, 185))
        gloss = gloss.filter(ImageFilter.GaussianBlur(20 * scale))
        gloss.putalpha(Image.composite(gloss.getchannel("A"), Image.new("L", (size, size), 0), cube_mask))
        canvas = Image.alpha_composite(canvas, gloss)

        rim = cube_mask.filter(ImageFilter.FIND_EDGES).filter(ImageFilter.GaussianBlur(1.2 * scale))
        rim_layer = Image.new("RGBA", (size, size), (255, 255, 255, 0))
        rim_layer.putalpha(rim.point(lambda v: int(v * 110 / 255)))
        canvas = Image.alpha_composite(canvas, rim_layer)

    if mono:
        # A themed-icon silhouette: white tiles with transparent seams.
        canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        d = ImageDraw.Draw(canvas)
        for origin, uvec, vvec in [(top_origin, top_u, top_v), (left_origin, left_u, left_v), (right_origin, right_u, right_v)]:
            for row in range(3):
                for col in range(3):
                    d.polygon(_tile_poly(origin, uvec, vvec, col, row), fill=(255, 255, 255, 255))
        canvas.putalpha(Image.composite(canvas.getchannel("A"), Image.new("L", (size, size), 0), cube_mask))

    return canvas

def save_rgb(img, path, size):
    path.parent.mkdir(parents=True, exist_ok=True)
    img.convert("RGB").resize((size, size), Image.Resampling.LANCZOS).save(path)


def save_rgba(img, path, size):
    path.parent.mkdir(parents=True, exist_ok=True)
    img.convert("RGBA").resize((size, size), Image.Resampling.LANCZOS).save(path)


def font(path, size):
    return ImageFont.truetype(path, size)


def make_launch_image():
    size = (720, 1040)
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    cube = make_cube(1200, transparent=True, cube_scale=0.76)
    cube = cube.resize((560, 560), Image.Resampling.LANCZOS)
    canvas.alpha_composite(cube, (80, 40))
    d = ImageDraw.Draw(canvas)
    georgia_bold = "/System/Library/Fonts/Supplemental/Georgia Bold.ttf"
    georgia_italic = "/System/Library/Fonts/Supplemental/Georgia Italic.ttf"
    title_font = font(georgia_bold, 66)
    accent_font = font(georgia_italic, 70)
    title = "Jelly Cube"
    title_w = d.textlength(title, font=title_font)
    accent_w = d.textlength("3D", font=accent_font)
    total = title_w + 6 + accent_w
    left = 360 - total / 2
    d.text((left, 675), title, fill=INK + (255,), font=title_font)
    d.text((left + title_w + 6, 664), "3D", fill=BERRY + (255,), font=accent_font)
    d.text((360, 790), "A  SOFT-BODY  PUZZLE", anchor="mm", fill=(111, 100, 126, 210), font=font(georgia_bold, 21))
    return canvas


def make_feature_graphic():
    w, h = 2048, 1000
    canvas = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    bg = vertical_gradient((w, h), (244, 238, 249), (214, 202, 232)).convert("RGBA")
    canvas = Image.alpha_composite(canvas, bg)
    canvas.alpha_composite(radial_glow((w, h), CREAM, 120), (0, 0))
    cube = make_cube(1000, transparent=True, cube_scale=0.82).resize((1000, 1000), Image.Resampling.LANCZOS)
    canvas.alpha_composite(cube, (-55, 20))
    d = ImageDraw.Draw(canvas)
    georgia_bold = "/System/Library/Fonts/Supplemental/Georgia Bold.ttf"
    georgia_italic = "/System/Library/Fonts/Supplemental/Georgia Italic.ttf"
    title_font = font(georgia_bold, 138)
    accent_font = font(georgia_italic, 142)
    title = "Jelly Cube"
    title_w = d.textlength(title, font=title_font)
    d.text((910, 330), title, fill=INK + (255,), font=title_font)
    d.text((910 + title_w + 28, 315), "3D", fill=BERRY + (255,), font=accent_font)
    d.text((918, 535), "A glossy soft-body twisty puzzle", fill=(82, 69, 96, 230), font=font(georgia_bold, 38))
    d.text((918, 635), "TWIST  ·  POKE  ·  DROP  ·  SOLVE", fill=(111, 100, 126, 210), font=font(georgia_bold, 23))
    # Small color swatches as a flavor signature.
    colors = [(255, 249, 236), (255, 212, 46), (119, 216, 60), (49, 87, 216), (213, 31, 61), (255, 122, 18)]
    for i, c in enumerate(colors):
        d.ellipse((918 + i * 70, 760, 962 + i * 70, 804), fill=c + (255,), outline=(255, 255, 255, 150), width=3)
    return canvas


def main():
    icon = make_cube(S, transparent=False)
    save_rgb(icon, BRAND_DIR / "app_icon_1024.png", 1024)
    save_rgb(icon, BRAND_DIR / "play_icon_512.png", 512)
    save_rgba(make_cube(S, transparent=True, cube_scale=0.78), BRAND_DIR / "cube_foreground_1024.png", 1024)
    save_rgba(make_cube(S, transparent=True, mono=True, cube_scale=0.78), BRAND_DIR / "cube_monochrome_1024.png", 1024)
    launch = make_launch_image()
    launch.resize((360, 520), Image.Resampling.LANCZOS).save(BRAND_DIR / "launch_logo_360.png")
    launch.save(BRAND_DIR / "launch_logo_720.png")
    feature = make_feature_graphic().convert("RGBA")
    # Flatten the feature graphic: Google Play expects an opaque image.
    fw, fh = 2048, 1000
    feature = feature.resize((fw, fh), Image.Resampling.LANCZOS)
    bg = Image.new("RGBA", (fw, fh))
    top = (244, 238, 249)
    bottom = (214, 202, 232)
    bpx = bg.load()
    for y in range(fh):
        t = y / max(1, fh - 1)
        c = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)) + (255,)
        for x in range(fw):
            bpx[x, y] = c
    feature = Image.alpha_composite(bg, feature).convert("RGB")
    feature.resize((1024, 500), Image.Resampling.LANCZOS).save(BRAND_DIR / "feature_graphic_1024x500.png")

    # iOS AppIcon
    base = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    contents = json.loads((base / "Contents.json").read_text())
    for image in contents["images"]:
        if "filename" not in image:
            continue
        size = image["size"].split("x")[0]
        scale = int(image["scale"].replace("x", ""))
        px = round(float(size) * scale)
        save_rgb(icon, base / image["filename"], px)

    # iOS launch image
    launch_set = ROOT / "ios/Runner/Assets.xcassets/LaunchImage.imageset"
    for name, px in [("LaunchImage.png", 360), ("LaunchImage@2x.png", 720), ("LaunchImage@3x.png", 1080)]:
        (launch.resize((px, int(px * 520 / 360)), Image.Resampling.LANCZOS)).save(launch_set / name)

    # Android legacy icons
    android_sizes = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
    for density, px in android_sizes.items():
        save_rgb(icon, ROOT / f"android/app/src/main/res/mipmap-{density}/ic_launcher.png", px)
        save_rgb(icon, ROOT / f"android/app/src/main/res/mipmap-{density}/ic_launcher_round.png", px)

    # Android adaptive foreground: cube inside the 66% safe zone of a 432 canvas.
    fg = make_cube(S, transparent=True, cube_scale=0.58)
    save_rgba(fg, ROOT / "android/app/src/main/res/drawable-nodpi/ic_launcher_foreground.png", 432)
    mono = make_cube(S, transparent=True, mono=True, cube_scale=0.58)
    save_rgba(mono, ROOT / "android/app/src/main/res/drawable-nodpi/ic_launcher_monochrome.png", 432)

    # Web icons
    save_rgb(icon, ROOT / "web/icons/Icon-192.png", 192)
    save_rgb(icon, ROOT / "web/icons/Icon-512.png", 512)
    save_rgb(icon, ROOT / "web/icons/Icon-maskable-192.png", 192)
    save_rgb(icon, ROOT / "web/icons/Icon-maskable-512.png", 512)
    save_rgb(icon, ROOT / "web/favicon.png", 48)
    save_rgb(icon, ROOT / "web/apple-touch-icon.png", 180)

    # macOS AppIcon
    mac = ROOT / "macos/Runner/Assets.xcassets/AppIcon.appiconset"
    for px in (16, 32, 64, 128, 256, 512, 1024):
        save_rgb(icon, mac / f"app_icon_{px}.png", px)

    # Store masters
    appstore = ROOT / "store/apple"
    play = ROOT / "store/google"
    appstore.mkdir(parents=True, exist_ok=True)
    play.mkdir(parents=True, exist_ok=True)
    save_rgb(icon, appstore / "icon-1024.png", 1024)
    save_rgb(icon, play / "icon-512.png", 512)
    feature.resize((1024, 500), Image.Resampling.LANCZOS).save(play / "feature-graphic-1024x500.png")
    print("Generated brand assets in", BRAND_DIR)


if __name__ == "__main__":
    main()
