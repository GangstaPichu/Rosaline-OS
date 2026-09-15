# system_files/

Everything under this directory is copied verbatim to `/` in the image
during the build (see the `COPY system_files /` line in the Containerfile).

Use it for static config and branding assets that don't need a shell
script to install them, for example:

- `usr/share/backgrounds/rosaline-os/` — desktop wallpapers
- `usr/share/plymouth/themes/rosaline-os/` — boot splash theme
- `usr/share/pixmaps/` — logo / icon used by os-release and the desktop
- `etc/skel/` — default files for new user home directories

Keep paths mirroring their final destination on the filesystem
(e.g. a file meant for `/etc/foo.conf` lives at `system_files/etc/foo.conf`).
