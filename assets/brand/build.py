"""
Lucy brand build: restores the mascot's linework, then generates every icon,
favicon, logo, banner and vector from it.

    python3 assets/brand/build.py            # from the repo root
    python3 assets/brand/build.py --no-trace # skip the slow vector traces

Needs Pillow and fontTools (and vtracer for the traced SVGs):
    python3 -m venv /tmp/lucy-brand && /tmp/lucy-brand/bin/pip install pillow fonttools vtracer

Inputs (assets/brand/source):
    Lucy.webp           portrait (head and shoulders)
    Lucy-Masthead.webp  head only
Fonts (assets/brand/fonts): Fredoka (display) and Nunito (text), SIL OFL.
Output: assets/brand/dist, copied to the site by `--site`.

The source renders came out of background removal with Lucy's black linework
cut out (fully transparent). `restore` puts it back: holes inside her
silhouette become ink, and a thin ink stroke goes round the outside.
"""

import math
import shutil
import sys
from pathlib import Path

from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

HERE = Path(__file__).resolve().parent
SOURCE = HERE / "source"
FONTS = HERE / "fonts"
OUT = HERE / "dist"
SITE_PUBLIC = HERE.parent.parent / "apps" / "site" / "public"
SITE_ASSETS = HERE.parent.parent / "apps" / "site" / "src" / "assets"

# Colours sampled from the mascot art.
MAGENTA = (240, 62, 222)
ORCHID = (192, 80, 234)
VIOLET = (135, 87, 226)
SKY = (91, 208, 248)
NIGHT_TOP = (43, 15, 87)
NIGHT_BOTTOM = (14, 8, 34)
INK = (5, 2, 10)
INK_TEXT = (24, 16, 48)
WORD = "Lucy"
STOPS = [(0.0, MAGENTA), (0.45, ORCHID), (0.72, VIOLET), (1.0, SKY)]


def hexc(c):
    return "#%02x%02x%02x" % c


# Linework ------------------------------------------------------------------------

def restore(path, outline=15, seal=41):
    art = Image.open(path).convert("RGBA")
    pad = outline * 2
    canvas = Image.new("RGBA", (art.width + pad * 2, art.height + pad * 2), (0, 0, 0, 0))
    canvas.alpha_composite(art, (pad, pad))
    solid = canvas.split()[3].point(lambda v: 255 if v > 8 else 0)
    # Lines that run out to the edge leave channels to the outside; seal them
    # (a close wider than the line width), then flood from outside.
    sealed = solid.filter(ImageFilter.MaxFilter(seal)).filter(ImageFilter.MinFilter(seal))
    ImageDraw.floodfill(sealed, (0, 0), 128)
    silhouette = sealed.point(lambda v: 0 if v == 128 else 255)
    silhouette = silhouette.filter(ImageFilter.MaxFilter(outline)).filter(ImageFilter.GaussianBlur(0.8))
    out = Image.new("RGBA", canvas.size, INK + (0,))
    out.putalpha(silhouette)
    out.alpha_composite(canvas)
    return out.crop(out.split()[3].point(lambda v: 255 if v > 8 else 0).getbbox())


# Fonts ---------------------------------------------------------------------------

def static_font(src, name, **axes):
    font = TTFont(src)
    instantiateVariableFont(font, axes, inplace=True)
    path = OUT / "fonts" / name
    path.parent.mkdir(parents=True, exist_ok=True)
    font.save(path)
    return path


# Drawing helpers -------------------------------------------------------------------

def gradient(size, top, bottom):
    w, h = size
    column = Image.new("RGB", (1, h))
    for y in range(h):
        t = y / max(1, h - 1)
        column.putpixel((0, y), tuple(round(a + (b - a) * t) for a, b in zip(top, bottom)))
    return column.resize((w, h))


def linear(size, stops, angle=0):
    w, h = size
    img = Image.new("RGB", size)
    px = img.load()
    rad = math.radians(angle)
    dx, dy = math.cos(rad), math.sin(rad)
    span = abs(w * dx) + abs(h * dy)
    for y in range(h):
        for x in range(w):
            t = min(1, max(0, ((x - w / 2) * dx + (y - h / 2) * dy) / span + 0.5))
            for i in range(len(stops) - 1):
                p0, c0 = stops[i]
                p1, c1 = stops[i + 1]
                if t <= p1:
                    u = (t - p0) / (p1 - p0) if p1 > p0 else 0
                    px[x, y] = tuple(round(a + (b - a) * u) for a, b in zip(c0, c1))
                    break
    return img


def glow(size, centre, radius, colour, strength):
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    cx, cy = centre
    ImageDraw.Draw(layer).ellipse((cx - radius, cy - radius, cx + radius, cy + radius), fill=colour + (round(255 * strength),))
    return layer.filter(ImageFilter.GaussianBlur(radius * 0.45))


def night(size):
    """Deep night violet with a magenta and sky glow behind Lucy's head."""
    w, h = size
    base = gradient(size, NIGHT_TOP, NIGHT_BOTTOM).convert("RGBA")
    base.alpha_composite(glow(size, (w * 0.32, h * 0.42), min(w, h) * 0.42, MAGENTA, 0.32))
    base.alpha_composite(glow(size, (w * 0.7, h * 0.36), min(w, h) * 0.38, SKY, 0.22))
    return base


def rounded_mask(size, radius):
    big = Image.new("L", (size[0] * 4, size[1] * 4), 0)
    ImageDraw.Draw(big).rounded_rectangle((0, 0, big.width - 1, big.height - 1), radius * 4, fill=255)
    return big.resize(size, Image.LANCZOS)


def place(canvas, art, height_ratio, top_ratio):
    h = round(canvas.height * height_ratio)
    w = round(art.width * h / art.height)
    canvas.alpha_composite(art.resize((w, h), Image.LANCZOS), ((canvas.width - w) // 2, round(canvas.height * top_ratio)))
    return canvas


def icon(head, size, height_ratio=0.98, top_ratio=0.06, rounded=True):
    canvas = place(night((size, size)), head, height_ratio, top_ratio)
    if rounded:
        canvas.putalpha(ImageChops.multiply(canvas.split()[3], rounded_mask(canvas.size, round(size * 0.225))))
    return canvas


def save(image, name, size=None):
    if size:
        image = image.resize((size, size), Image.LANCZOS)
    image.save(OUT / name, optimize=True)


# Wordmark --------------------------------------------------------------------------

def wordmark_svg(font_path, defs, fill, name):
    font = TTFont(font_path)
    glyphs, cmap = font.getGlyphSet(), font.getBestCmap()
    ascent, descent = font["hhea"].ascent, -font["hhea"].descent
    x, paths = 0, []
    for ch in WORD:
        glyph = cmap[ord(ch)]
        pen = SVGPathPen(glyphs)
        glyphs[glyph].draw(TransformPen(pen, (1, 0, 0, -1, x, ascent)))
        paths.append(pen.getCommands())
        x += glyphs[glyph].width
    (OUT / name).write_text(
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {x} {ascent + descent}" role="img" aria-label="Lucy">'
        f'<title>Lucy</title>{defs}<path fill="{fill}" d="{" ".join(paths)}"/></svg>\n'
    )


def wordmark_png(font_path, px, colour=None):
    font = ImageFont.truetype(str(font_path), px)
    box = font.getbbox(WORD)
    mask = Image.new("L", (box[2] - box[0] + 4, box[3] - box[1] + 4), 0)
    ImageDraw.Draw(mask).text((2 - box[0], 2 - box[1]), WORD, font=font, fill=255)
    fill = (linear(mask.size, STOPS, angle=12) if colour is None else Image.new("RGB", mask.size, colour)).convert("RGBA")
    fill.putalpha(mask)
    return fill


def lockup(head, font_path, height, colour=None):
    art = head.resize((round(head.width * height / head.height), height), Image.LANCZOS)
    word = wordmark_png(font_path, round(height * 0.52), colour)
    gap = round(height * 0.12)
    canvas = Image.new("RGBA", (art.width + gap + word.width, height), (0, 0, 0, 0))
    canvas.alpha_composite(art, (0, 0))
    canvas.alpha_composite(word, (art.width + gap, (height - word.height) // 2 + round(height * 0.03)))
    return canvas


def banner(portrait, display, text, size, title_px, tagline, name):
    w, h = size
    canvas = night(size)
    art_h = round(h * 0.96)
    art = portrait.resize((round(portrait.width * art_h / portrait.height), art_h), Image.LANCZOS)
    canvas.alpha_composite(art, (w - art.width - round(w * 0.05), h - art_h))
    word = wordmark_png(display, title_px)
    left, top = round(w * 0.07), round(h * 0.3)
    canvas.alpha_composite(word, (left, top))
    font = ImageFont.truetype(str(text), round(title_px * 0.3))
    ImageDraw.Draw(canvas).text((left + 4, top + word.height + round(title_px * 0.18)), tagline, font=font, fill=(236, 230, 255))
    canvas.convert("RGB").save(OUT / name, optimize=True)


# Build -----------------------------------------------------------------------------

def main(trace=True, site=False):
    OUT.mkdir(exist_ok=True)
    portrait = restore(SOURCE / "Lucy.webp")
    head = restore(SOURCE / "Lucy-Masthead.webp")
    display = static_font(FONTS / "Fredoka[wdth,wght].ttf", "Fredoka-SemiBold.ttf", wght=600, wdth=100)
    text = static_font(FONTS / "Nunito[wght].ttf", "Nunito-SemiBold.ttf", wght=600)

    # Mascot renders with linework restored.
    for name, art in (("lucy-portrait", portrait), ("lucy-head", head)):
        art.save(OUT / f"{name}.png", optimize=True)
        art.save(OUT / f"{name}.webp", quality=90, method=6)
        art.resize((256, round(art.height * 256 / art.width)), Image.LANCZOS).save(OUT / f"{name}-256.webp", quality=90, method=6)

    # App icons.
    save(icon(head, 1024), "icon-1024.png")
    save(icon(head, 1024), "icon-512.png", 512)
    save(icon(head, 1024), "icon-192.png", 192)
    save(icon(head, 1024, rounded=False).convert("RGB"), "apple-touch-icon.png", 180)  # iOS rounds it
    save(icon(head, 1024, 0.8, 0.14, rounded=False), "icon-maskable-512.png", 512)  # 80% safe zone
    save(icon(head, 1024, rounded=False).convert("RGB"), "roblox-icon-512.png", 512)  # Roblox rounds it

    # Favicons: a little tighter so she reads at 32 px, headband included.
    face = icon(head, 1024, 1.1, 0.0)
    for px in (16, 32, 48):
        save(face, f"favicon-{px}.png", px)
    face.resize((256, 256), Image.LANCZOS).save(OUT / "favicon.ico", sizes=[(16, 16), (32, 32), (48, 48)])

    # Wordmark and lockups.
    stops = "".join(f'<stop offset="{p}" stop-color="{hexc(c)}"/>' for p, c in STOPS)
    defs = f'<defs><linearGradient id="lucy-word" x1="0" y1="0" x2="1" y2="0.25">{stops}</linearGradient></defs>'
    wordmark_svg(display, defs, "url(#lucy-word)", "wordmark.svg")
    wordmark_svg(display, "", "#ffffff", "wordmark-white.svg")
    wordmark_svg(display, "", hexc(INK_TEXT), "wordmark-ink.svg")
    wordmark_png(display, 256).save(OUT / "wordmark.png", optimize=True)
    lockup(head, display, 512).save(OUT / "logo-lockup.png", optimize=True)
    lockup(head, display, 512, INK_TEXT).save(OUT / "logo-lockup-ink.png", optimize=True)

    # Social and Roblox banners.
    banner(portrait, display, text, (1200, 630), 200, "A UI kit for Roblox", "og.png")
    banner(portrait, display, text, (1920, 1080), 320, "A UI kit for Roblox", "roblox-thumbnail-1920x1080.png")

    # Master vectors: a high-fidelity trace of the restored art (large; for print and big displays).
    if trace:
        import vtracer

        for name in ("lucy-portrait", "lucy-head"):
            vtracer.convert_image_to_svg_py(
                str(OUT / f"{name}.png"), str(OUT / f"{name}.svg"), colormode="color", hierarchical="stacked",
                mode="spline", corner_threshold=60, length_threshold=4.0, max_iterations=10, splice_threshold=45,
                filter_speckle=4, color_precision=8, layer_difference=3, path_precision=1,
            )

    if site:
        SITE_PUBLIC.mkdir(parents=True, exist_ok=True)
        for name in ("favicon.ico", "favicon-32.png", "apple-touch-icon.png", "icon-192.png", "icon-512.png",
                     "icon-maskable-512.png", "og.png"):
            shutil.copy(OUT / name, SITE_PUBLIC / name)
        for name in ("lucy-head-256.webp", "lucy-portrait.webp", "wordmark.svg", "wordmark-ink.svg"):
            shutil.copy(OUT / name, SITE_ASSETS / name)

    print("\n".join(sorted(p.name for p in OUT.iterdir())))


if __name__ == "__main__":
    main(trace="--no-trace" not in sys.argv, site="--site" in sys.argv)
