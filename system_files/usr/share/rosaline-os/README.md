# system_files/

Everything under this directory is copied verbatim to `/` in the image
during the build (see the `COPY system_files /` line in the Containerfile).

Use it for static config and branding assets that don't need a shell
script to install them. Keep paths mirroring their final destination on
the filesystem (e.g. a file meant for `/etc/foo.conf` lives at
`system_files/etc/foo.conf`).

## What's here today

- `usr/share/icons/hicolor/**/apps/rosaline-os.png` (+ `scalable/…svg`) —
  the app/distro icon, in every standard hicolor size
- `usr/share/pixmaps/rosaline-os.png` — single fallback icon for tools
  that don't read the hicolor theme
- `usr/share/backgrounds/rosaline-os/rosaline-default.png` — default
  desktop wallpaper (3840×2160)
- `usr/share/gnome-background-properties/rosaline-os.xml` — makes the
  wallpaper show up by name in the GNOME/Cinnamon background picker
- `usr/share/plymouth/themes/rosaline-os/` — boot splash theme (script
  plugin: wordmark + spinner)
- `etc/dconf/` — sets the wallpaper as the default for new users

All of these are generated from source files in `assets/branding/` — see
that directory's `render.py` to regenerate after an edit, rather than
hand-editing the PNGs here.
