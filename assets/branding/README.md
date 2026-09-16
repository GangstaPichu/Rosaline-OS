# assets/branding/

Editable source files for Rosaline OS's visual identity. These are not
copied into the image directly — `render.py` rasterizes them into the
actual installed files under `system_files/`.

- `mark.svg` — the icon/logo mark alone (a four-point compass rose:
  one point per merged distro, unified around a center gem). Used for
  the hicolor icon theme, pixmaps, and as the base of the wallpaper's
  watermark.
- `wordmark.svg` — mark + "ROSALINE / OPERATING SYSTEM" lockup, on a
  transparent background. Used as the Plymouth boot logo.
- `wallpaper.svg` — the default desktop wallpaper (dusk gradient,
  colored aura, a scatter of stars, a faint travelled-path line, and
  the watermark mark), 3840×2160.
- `render.py` — regenerates every PNG/SVG under `system_files/` from the
  three files above.

## Editing

1. Edit the relevant `.svg` (plain text, no special tools required —
   any vector editor like Inkscape works too if you prefer a GUI).
   Careful with XML comments: `--` isn't allowed anywhere inside one,
   only immediately before the closing `-->` — cairosvg fails to parse
   the whole file otherwise (found the hard way while writing this
   version).
2. `pip install cairosvg pillow` (once).
3. `python3 assets/branding/render.py` from the repo root.
4. Check `git diff --stat system_files/` to see what changed, and spot
   check a couple of the regenerated PNGs before committing.

## Concept

"Rosaline" reads two ways on purpose: a rose bloom, and a nod to
*Atelier Resleriana*'s cozy-but-adventurous tone. The mark leans into
both at once by being a **compass rose** — a shape that's already both
a flower and a navigation symbol before you even add a theme to it.
Each of the four points is still one petal per merged distro (Bazzite,
SteamOS, Nobara, Mint), same idea as the original mark, just redrawn
as a symmetric needle/kite shape at true 90-degree spacing (a real
compass rose reads more intentional than the original's organic,
unevenly-spaced petals) and split into a lighter/darker half each,
like a faceted gem or a needle catching light from one side. Small
ticks between the four main points echo a compass rose's
intercardinal marks.

The wallpaper carries the "cozy" and "adventurous" halves separately:
a warm dusk sky (not a cold night one) and a scatter of small stars
for cozy, a faint dashed path curving through the scene for
adventurous, without literally drawing a map.

## Palette

| Role              | Hex       |
|-------------------|-----------|
| Dusk sky (top)    | `#242038` |
| Dusk sky (mid)    | `#362C46` |
| Dusk sky (bottom) | `#4E3A47` |
| Rose (light/dark) | `#F6AEBB` / `#E06B82` |
| Gold (light/dark) | `#F8DDA0` / `#E5AC49` |
| Lavender (l/dark) | `#D2C2F2` / `#9B7FD1` |
| Teal (light/dark) | `#ABDED2` / `#5CA99B` |
| Gem gradient      | `#FFF8E7` → `#F6D48C` → `#D9A84E` |
| Outline (muted)   | `#7A5568` |
| Off-white         | `#F5EDE9` |

Softer/pastel versions of the original palette's four hues, not a
different set of colors entirely — the goal was "the same identity,
gentler," not a from-scratch rebrand. The four point colors still
aren't meant to map 1:1 onto SteamOS/Bazzite/Nobara/Mint's actual
brand colors; the shape carries the "four distros merged into one"
idea, the color is just there to read well and stay distinguishable
point to point.
