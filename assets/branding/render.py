#!/usr/bin/env python3
"""
Rasterizes Rosaline OS's SVG brand sources into the PNG/SVG files the
image actually ships under system_files/. Re-run this after editing
mark.svg / wordmark.svg / wallpaper.svg.

Requires: cairosvg, pillow  (pip install cairosvg pillow)
"""
import io
import math
import pathlib

import cairosvg
from PIL import Image, ImageDraw

HERE = pathlib.Path(__file__).parent
REPO_ROOT = HERE.parent.parent
SYS = REPO_ROOT / "system_files"

MARK_SVG = HERE / "mark.svg"
WORDMARK_SVG = HERE / "wordmark.svg"
WALLPAPER_SVG = HERE / "wallpaper.svg"
MASCOT_SVG = HERE / "mascot.svg"

ICON_SIZES = [16, 22, 24, 32, 48, 64, 128, 256, 512]

PETAL_COLORS = ["#F0879B", "#F3C56E", "#B79FE3", "#7FC4B8"]


def render_icons():
    scalable_dir = SYS / "usr/share/icons/hicolor/scalable/apps"
    scalable_dir.mkdir(parents=True, exist_ok=True)
    (scalable_dir / "rosaline-os.svg").write_text(MARK_SVG.read_text())

    for size in ICON_SIZES:
        out_dir = SYS / f"usr/share/icons/hicolor/{size}x{size}/apps"
        out_dir.mkdir(parents=True, exist_ok=True)
        cairosvg.svg2png(
            url=str(MARK_SVG),
            write_to=str(out_dir / "rosaline-os.png"),
            output_width=size,
            output_height=size,
        )

    pixmaps_dir = SYS / "usr/share/pixmaps"
    pixmaps_dir.mkdir(parents=True, exist_ok=True)
    cairosvg.svg2png(
        url=str(MARK_SVG),
        write_to=str(pixmaps_dir / "rosaline-os.png"),
        output_width=256,
        output_height=256,
    )
    print("icons: done")


def render_wallpaper():
    bg_dir = SYS / "usr/share/backgrounds/rosaline-os"
    bg_dir.mkdir(parents=True, exist_ok=True)
    cairosvg.svg2png(
        url=str(WALLPAPER_SVG),
        write_to=str(bg_dir / "rosaline-default.png"),
        output_width=3840,
        output_height=2160,
    )

    props_dir = SYS / "usr/share/gnome-background-properties"
    props_dir.mkdir(parents=True, exist_ok=True)
    (props_dir / "rosaline-os.xml").write_text(
        """<?xml version="1.0"?>
<!DOCTYPE wallpapers SYSTEM "gnome-wp-list.dtd">
<wallpapers>
  <wallpaper deleted="false">
    <name>Rosaline OS</name>
    <filename>/usr/share/backgrounds/rosaline-os/rosaline-default.png</filename>
    <options>zoom</options>
    <shade_type>solid</shade_type>
    <pcolor>#242038</pcolor>
    <scolor>#242038</scolor>
  </wallpaper>
</wallpapers>
"""
    )
    print("wallpaper: done")


def render_plymouth():
    theme_dir = SYS / "usr/share/plymouth/themes/rosaline-os"
    theme_dir.mkdir(parents=True, exist_ok=True)

    # boot logo: the wordmark, sized for a 1080p-and-up boot screen
    cairosvg.svg2png(
        url=str(WORDMARK_SVG),
        write_to=str(theme_dir / "logo.png"),
        output_width=980,
        output_height=280,
    )

    # spinner ring: four petal-colored arcs, drawn directly with Pillow
    # (rotated at runtime by the plymouth script, not pre-baked as frames)
    size = 220
    scale = 4  # supersample then downscale for smoother edges
    big = size * scale
    ring = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    draw = ImageDraw.Draw(ring)
    line_w = 16 * scale
    pad = line_w
    bbox = [pad, pad, big - pad, big - pad]
    gap = 10
    sweep = 90 - gap
    for i, color in enumerate(PETAL_COLORS):
        start = i * 90 + gap / 2 - 90  # -90 so segment 0 starts at the top
        draw.arc(bbox, start=start, end=start + sweep, fill=color, width=line_w)
    ring = ring.resize((size, size), Image.LANCZOS)
    ring.save(theme_dir / "spinner.png")

    print("plymouth assets: done")


def render_mascots():
    # mascot.svg is a single 800x640 canvas with two characters side by
    # side (Rosie left half, Sage right half) so they share one set of
    # <defs> (the crown, the body template) -- render once at 2x for
    # crispness, then split into the two files build.sh actually
    # installs over KDE's own Konqi/Katie art.
    out_dir = SYS / "usr/share/rosaline-os"
    out_dir.mkdir(parents=True, exist_ok=True)

    scale = 2
    full = cairosvg.svg2png(
        url=str(MASCOT_SVG),
        output_width=800 * scale,
        output_height=640 * scale,
    )
    canvas = Image.open(io.BytesIO(full))
    half = canvas.width // 2
    canvas.crop((0, 0, half, canvas.height)).save(out_dir / "mascot-a.png")
    canvas.crop((half, 0, canvas.width, canvas.height)).save(out_dir / "mascot-b.png")
    print("mascots: done")


if __name__ == "__main__":
    render_icons()
    render_wallpaper()
    render_plymouth()
    render_mascots()
