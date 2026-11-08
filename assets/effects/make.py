"""
Lucy's effect textures: white, with all the shape in the alpha, so code tints them (ImageColor3).

  python3 assets/effects/make.py      writes streak.png and glow.png next to this file

streak.png  one ray of light pointing up: widest and brightest at the base (the bottom edge),
            fading and narrowing to a point at the top, soft across its width
glow.png    a round glow: a hot middle falling off smoothly to nothing at the edge
"""
from pathlib import Path

import numpy as np
from PIL import Image

HERE = Path(__file__).parent


def save(alpha: np.ndarray, name: str) -> None:
    a = (np.clip(alpha, 0, 1) * 255).round().astype(np.uint8)
    rgba = np.dstack([np.full_like(a, 255)] * 3 + [a])
    Image.fromarray(rgba).save(HERE / name)


def streak(width: int = 64, height: int = 512) -> np.ndarray:
    y, x = np.mgrid[0:height, 0:width].astype(float)
    s = 1 - (y + 0.5) / height  # 0 at the base (bottom), 1 at the tip (top)
    u = ((x + 0.5) / width - 0.5) * 2  # -1..1 across
    half = np.maximum(1 - s, 1e-3)  # the ray narrows to a point
    across = np.exp(-((u / half) ** 2) * 3.2)  # soft edges
    along = (1 - s) ** 1.6  # dimmer further out
    base = np.clip(s / 0.04, 0, 1)  # no hard edge at the base
    return across * along * base


def glow(size: int = 256) -> np.ndarray:
    y, x = np.mgrid[0:size, 0:size].astype(float)
    r = np.hypot((x + 0.5) / size - 0.5, (y + 0.5) / size - 0.5) * 2  # 0 middle, 1 edge
    soft = np.clip(1 - r, 0, 1) ** 2.4
    hot = np.exp(-((r / 0.22) ** 2))
    return np.clip(0.55 * soft + 0.45 * hot, 0, 1) * np.clip((1 - r) / 0.05, 0, 1)


if __name__ == "__main__":
    save(streak(), "streak.png")
    save(glow(), "glow.png")
    print("wrote", HERE / "streak.png", HERE / "glow.png")
