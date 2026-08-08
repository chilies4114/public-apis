#!/usr/bin/env python3
"""Render the 1024x1024 App Store icon for Ask the Orb.

A glass fortune-telling orb on a stand, lit from within. Drawn procedurally so
the icon can be regenerated at any size and stays in sync with the in-app
`OrbView`, which uses the same palette and light direction.

Xcode 14+ only needs the single 1024pt slot in the asset catalog; smaller sizes
are derived at build time. The output is deliberately flat RGB with no alpha
channel — App Store Connect rejects an icon carrying transparency at upload
time, long before review.

Usage: python3 scripts/generate_app_icon.py
"""

from __future__ import annotations

import math
import os

from PIL import Image, ImageChops, ImageDraw, ImageFilter

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

# Geometry, as fractions of the canvas. The orb sits slightly high so the stand
# has room without the whole composition drifting off centre.
ORB_CENTER_Y = 0.455
ORB_RADIUS = 0.255
LIGHT = (-0.34, -0.40)  # highlight offset from centre, in orb radii

# Palette shared with Theme.swift / OrbView.swift.
CORE_DEEP = (26, 20, 62)
CORE_MID = (46, 32, 110)
GLASS_RIM = (128, 140, 255)
MIST_WARM = (150, 108, 236)
MIST_COOL = (110, 176, 255)


def lerp(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def background(size: int) -> Image.Image:
    """Vertical deep-space gradient matching the app's CosmicBackground."""
    top, mid, bottom = (30, 22, 68), (16, 14, 42), (7, 7, 20)
    canvas = Image.new("RGB", (size, size))
    draw = ImageDraw.Draw(canvas)
    for y in range(size):
        t = y / (size - 1)
        color = lerp(top, mid, t * 2) if t < 0.5 else lerp(mid, bottom, (t - 0.5) * 2)
        draw.line([(0, y), (size, y)], fill=color)
    return canvas


def halo(size: int) -> Image.Image:
    """Light thrown by the orb onto the space around it."""
    layer = Image.new("RGB", (size, size), (0, 0, 0))
    draw = ImageDraw.Draw(layer)
    cx, cy = size / 2, size * ORB_CENTER_Y
    base = size * ORB_RADIUS

    steps = 70
    for step in range(steps, 0, -1):
        t = step / steps
        r = base * (0.95 + 0.95 * t)
        i = (1 - t) ** 2.2
        draw.ellipse(
            [cx - r, cy - r, cx + r, cy + r],
            fill=(round(96 * i), round(70 * i), round(200 * i)),
        )
    return layer.filter(ImageFilter.GaussianBlur(size * 0.05))


def stand(size: int) -> Image.Image:
    """A cradle for the orb, plus the shadow it casts.

    Drawn before the orb so the sphere covers the cradle's top half — that
    overlap is what makes the orb look seated rather than pasted on.
    """
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))

    cx = size / 2
    radius = size * ORB_RADIUS
    orb_bottom = size * ORB_CENTER_Y + radius

    # Contact shadow: soft, wide, and low-contrast so it grounds the orb
    # without reading as a second object.
    shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    sw, sh = radius * 1.45, radius * 0.30
    sy = orb_bottom + radius * 0.16
    ImageDraw.Draw(shadow).ellipse(
        [cx - sw, sy - sh, cx + sw, sy + sh], fill=(4, 3, 14, 190)
    )
    layer.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(size * 0.030)))

    draw = ImageDraw.Draw(layer)
    cradle_w = radius * 1.34
    cradle_h = radius * 0.40
    top = orb_bottom - cradle_h * 0.62
    box = [cx - cradle_w / 2, top, cx + cradle_w / 2, top + cradle_h]

    draw.ellipse(box, fill=(31, 24, 60, 255))
    # Lit front edge, picking up the glow from the orb above it.
    draw.arc(box, start=8, end=172, fill=(126, 112, 210, 225),
             width=max(1, round(size * 0.0055)))

    return layer


def orb(size: int) -> Image.Image:
    """Glass sphere: dark core, luminous rim, mist inside, highlight on top."""
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)

    cx, cy = size / 2, size * ORB_CENTER_Y
    radius = size * ORB_RADIUS

    # Radial body drawn from the rim inwards. Unlike the old pool ball this is
    # bright at the edge and dark at the centre, which is what makes it read as
    # transparent glass rather than a solid sphere.
    steps = 240
    for step in range(steps, 0, -1):
        t = step / steps  # 1.0 at the rim, ~0 at the core
        r = radius * t
        if t > 0.88:
            color = lerp(CORE_MID, GLASS_RIM, (t - 0.88) / 0.12)
        else:
            color = lerp(CORE_DEEP, CORE_MID, (t / 0.88) ** 1.6)
        ox = LIGHT[0] * radius * (1 - t) * 0.30
        oy = LIGHT[1] * radius * (1 - t) * 0.30
        draw.ellipse(
            [cx + ox - r, cy + oy - r, cx + ox + r, cy + oy + r],
            fill=color + (255,),
        )

    # Interior light. A glow anchored below centre plus one cool wisp reads as
    # a lit orb; discrete blobs just look like smudges once the icon is 60px.
    mist = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    md = ImageDraw.Draw(mist)

    gx, gy = cx, cy + radius * 0.16
    steps = 48
    for step in range(steps, 0, -1):
        t = step / steps
        r = radius * 0.80 * t
        i = (1 - t) ** 1.7
        md.ellipse(
            [gx - r, gy - r * 0.86, gx + r, gy + r * 0.86],
            fill=MIST_WARM + (round(150 * i),),
        )

    md.ellipse(
        [cx + radius * 0.02, cy - radius * 0.52,
         cx + radius * 0.66, cy - radius * 0.02],
        fill=MIST_COOL + (95,),
    )
    mist = mist.filter(ImageFilter.GaussianBlur(size * 0.055))

    clip = Image.new("L", (size, size), 0)
    ImageDraw.Draw(clip).ellipse(
        [cx - radius, cy - radius, cx + radius, cy + radius], fill=255
    )
    layer.alpha_composite(Image.composite(mist, Image.new("RGBA", (size, size), (0, 0, 0, 0)), clip))

    # Rim: a bright arc on the lit side fading around the sphere.
    rim = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    rd = ImageDraw.Draw(rim)
    box = [cx - radius, cy - radius, cx + radius, cy + radius]
    rd.arc(box, start=150, end=330, fill=(210, 220, 255, 210), width=max(1, round(size * 0.007)))
    rd.arc(box, start=330, end=150, fill=(150, 140, 235, 110), width=max(1, round(size * 0.005)))
    layer.alpha_composite(rim.filter(ImageFilter.GaussianBlur(size * 0.002)))

    # Specular highlight, and the small bounce light opposite it.
    spec = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    sd = ImageDraw.Draw(spec)
    sx, sy = cx + LIGHT[0] * radius * 0.56, cy + LIGHT[1] * radius * 0.56
    sd.ellipse(
        [sx - radius * 0.175, sy - radius * 0.105, sx + radius * 0.175, sy + radius * 0.105],
        fill=(255, 255, 255, 175),
    )
    layer.alpha_composite(spec.filter(ImageFilter.GaussianBlur(size * 0.020)))

    return layer


def sparks(size: int) -> Image.Image:
    """Three small four-point stars, echoing the idle orb's moon.stars glyph."""
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    cx, cy = size / 2, size * ORB_CENTER_Y
    radius = size * ORB_RADIUS

    # (angle in degrees, distance in orb radii, size in orb radii)
    for angle, distance, scale in ((214, 1.24, 0.085), (318, 1.20, 0.060), (272, 1.36, 0.045)):
        rad = math.radians(angle)
        px = cx + math.cos(rad) * radius * distance
        py = cy + math.sin(rad) * radius * distance
        arm = radius * scale
        waist = arm * 0.16
        draw.polygon(
            [(px, py - arm), (px + waist, py - waist), (px + arm, py),
             (px + waist, py + waist), (px, py + arm), (px - waist, py + waist),
             (px - arm, py), (px - waist, py - waist)],
            fill=(232, 236, 255, 235),
        )
    return layer.filter(ImageFilter.GaussianBlur(size * 0.0016))


def main() -> None:
    big = SIZE * SUPERSAMPLE

    canvas = ImageChops.screen(background(big), halo(big)).convert("RGBA")
    canvas = Image.alpha_composite(canvas, stand(big))
    canvas = Image.alpha_composite(canvas, orb(big))
    canvas = Image.alpha_composite(canvas, sparks(big))

    icon = canvas.convert("RGB").resize((SIZE, SIZE), Image.LANCZOS)

    os.makedirs(os.path.dirname(OUTPUT), exist_ok=True)
    icon.save(OUTPUT, "PNG", optimize=True)

    reopened = Image.open(OUTPUT)
    assert reopened.mode == "RGB", f"icon must have no alpha channel, got {reopened.mode}"
    assert reopened.size == (SIZE, SIZE), f"icon must be {SIZE}x{SIZE}, got {reopened.size}"
    print(f"Wrote {OUTPUT} ({reopened.size[0]}x{reopened.size[1]}, mode {reopened.mode})")


if __name__ == "__main__":
    main()
