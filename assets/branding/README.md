# assets/branding/

Editable source files for Rosaline OS's visual identity. These are not
copied into the image directly — `render.py` rasterizes them into the
actual installed files under `system_files/`.

- `mark.svg` — the icon/logo mark alone (four-petal bloom: one petal per
  merged distro, unified around a center gem). Used for the hicolor icon
  theme, pixmaps, and as the base of the wallpaper's watermark.
- `wordmark.svg` — mark + "ROSALINE / OPERATING SYSTEM" lockup, on a
  transparent background. Used as the Plymouth boot logo.
- `wallpaper.svg` — the default desktop wallpaper (dark gradient +
  colored aura + watermark bloom), 3840×2160.
- `render.py` — regenerates every PNG/SVG under `system_files/` from the
  three files above.

## Editing

1. Edit the relevant `.svg` (plain text, no special tools required —
   any vector editor like Inkscape works too if you prefer a GUI).
2. `pip install cairosvg pillow` (once).
3. `python3 assets/branding/render.py` from the repo root.
4. Check `git diff --stat system_files/` to see what changed, and spot
   check a couple of the regenerated PNGs before committing.

## Palette

| Role          | Hex       |
|---------------|-----------|
| Ink (base)    | `#16121A` |
| Ink (light)   | `#1B1420` |
| Rose          | `#E0355F` |
| Violet        | `#7C4DBB` |
| Gold          | `#E0A83A` |
| Teal          | `#2E9CA6` |
| Off-white     | `#F5EDE9` |

The four petal colors (rose, violet, gold, teal) aren't meant to map
1:1 onto SteamOS/Bazzite/Nobara/Mint's actual brand colors — they're a
distinct jewel-tone palette chosen to read well together, with the
"four petals, one bloom" shape carrying the "four distros merged into
one" idea instead.
