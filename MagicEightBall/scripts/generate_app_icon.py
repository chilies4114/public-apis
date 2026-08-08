#!/usr/bin/env python3
"""Render the 1024x1024 App Store icon for Eight Ball Oracle.

Xcode 14+ only needs the single 1024pt slot in the asset catalog; smaller sizes
are derived at build time. The output is deliberately flat RGB with no alpha
channel — App Store Connect rejects an icon carrying transparency at upload
time, long before review.

Usage: python3 scripts/generate_app_icon.py
"""

from __future__ import annotations

import os

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

SIZE = 1024
SUPERSAMPLE = 2  # draw at 2x, downsample once, so every edge is antialiased

OUTPUT = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "App",
    "Resources",
    "Assets.xcassets",
    "AppIcon.appiconset",
    "AppIcon-1024.png",
)

FONT_CANDIDATES = [
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
    "/usr/share/fonts/truetype/freefont/FreeSansBold.ttf",
    "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
]

BALL_CENTER_Y = 0.47  # fraction of canvas height
BALL_RADIUS = 0.335  # fraction of canvas width


def load_font(size: int) -> ImageFont.FreeTypeFont:
    for path in FONT_CANDIDATES:
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    raise SystemExit("No bold sans-serif font found (tried: %s)" % ", ".join(FONT_CANDIDATES))


def lerp(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def background(size: int) -> Image.Image:
    """Vertical deep-space gradient matching the app's CosmicBackground."""
    top, mid, bottom = (36, 26, 82), (18, 16, 48), (8, 8, 22)
    canvas = Image.new("RGB", (size, size))
    draw = ImageDraw.Draw(canvas)

    for y in range(size):
        t = y / (size - 1)
        color = lerp(top, mid, t * 2) if t < 0.5 else lerp(mid, bottom, (t - 0.5) * 2)
        draw.line([(0, y), (size, y)], fill=color)
    return canvas


def glow(size: int) -> Image.Image:
    """Soft violet halo, screen-blended over the background."""
    layer = Image.new("RGB", (size, size), (0, 0, 0))
    draw = ImageDraw.Draw(layer)
    cx, cy = size / 2, size * BALL_CENTER_Y
    base = size * BALL_RADIUS

    steps = 60
    for step in range(steps, 0, -1):
        t = step / steps
        r = base * (0.9 + 0.85 * t)
        intensity = (1 - t) ** 2
        draw.ellipse(
            [cx - r, cy - r, cx + r, cy + r],
            fill=(round(110 * intensity), round(88 * intensity), round(215 * intensity)),
        )

    return layer.filter(ImageFilter.GaussianBlur(size * 0.045))


def ball(size: int) -> Image.Image:
    """Shaded black sphere with a specular highlight and a rim light."""
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)

    cx, cy = size / 2, size * BALL_CENTER_Y
    radius = size * BALL_RADIUS
    light_x, light_y = cx - radius * 0.36, cy - radius * 0.42

    # Concentric ellipses drifting toward the light source approximate a
    # radial gradient anchored off-centre, which is what makes it read as a
    # sphere instead of a flat disc.
    steps = 220
    for step in range(steps, 0, -1):
        t = step / steps
        r = radius * t
        shade = (1.0 - t) ** 1.5
        value = round(6 + 62 * shade)
        ox = (light_x - cx) * (1 - t) * 0.55
        oy = (light_y - cy) * (1 - t) * 0.55
        draw.ellipse(
            [cx + ox - r, cy + oy - r, cx + ox + r, cy + oy + r],
            fill=(value, value, min(255, value + 4), 255),
        )

    rim = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(rim).ellipse(
        [cx - radius, cy - radius, cx + radius, cy + radius],
        outline=(150, 150, 195, 90),
        width=max(1, round(size * 0.005)),
    )
    layer.alpha_composite(rim)

    spec = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    sx, sy = cx - radius * 0.34, cy - radius * 0.46
    sw, sh = radius * 0.46, radius * 0.28
    ImageDraw.Draw(spec).ellipse(
        [sx - sw / 2, sy - sh / 2, sx + sw / 2, sy + sh / 2],
        fill=(255, 255, 255, 150),
    )
    layer.alpha_composite(spec.filter(ImageFilter.GaussianBlur(size * 0.016)))

    return layer


def eight_badge(size: int) -> Image.Image:
    """The white disc with the 8, centred on the ball."""
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)

    cx, cy = size / 2, size * BALL_CENTER_Y
    badge_r = size * BALL_RADIUS * 0.40
    draw.ellipse([cx - badge_r, cy - badge_r, cx + badge_r, cy + badge_r], fill=(255, 255, 255, 255))

    font = load_font(round(badge_r * 1.42))
    bbox = draw.textbbox((0, 0), "8", font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    draw.text((cx - tw / 2 - bbox[0], cy - th / 2 - bbox[1]), "8", font=font, fill=(12, 12, 16, 255))

    return layer


def main() -> None:
    big = SIZE * SUPERSAMPLE

    canvas = ImageChops.screen(background(big), glow(big)).convert("RGBA")
    canvas = Image.alpha_composite(canvas, ball(big))
    canvas = Image.alpha_composite(canvas, eight_badge(big))

    icon = canvas.convert("RGB").resize((SIZE, SIZE), Image.LANCZOS)

    os.makedirs(os.path.dirname(OUTPUT), exist_ok=True)
    icon.save(OUTPUT, "PNG", optimize=True)

    reopened = Image.open(OUTPUT)
    assert reopened.mode == "RGB", f"icon must have no alpha channel, got {reopened.mode}"
    assert reopened.size == (SIZE, SIZE), f"icon must be {SIZE}x{SIZE}, got {reopened.size}"
    print(f"Wrote {OUTPUT} ({reopened.size[0]}x{reopened.size[1]}, mode {reopened.mode})")


if __name__ == "__main__":
    main()
