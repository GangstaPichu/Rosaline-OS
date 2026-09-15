#!/usr/bin/env bash
#
# Runs inside the image build (see Containerfile). Layers Rosaline OS's
# additions onto the Bazzite base: a Cinnamon desktop option (Mint-style
# daily-driver session), OS branding, and a couple of quality-of-life
# packages that aren't already part of Bazzite/Nobara's gaming stack.
set -ouex pipefail

# Cinnamon gives people the option of a traditional, low-friction desktop
# (a la Linux Mint) alongside Bazzite's existing KDE Plasma / gamescope
# sessions -- SDDM lets users pick a session at login, nothing here removes
# the gaming-focused defaults.
dnf5 install -y \
    cinnamon-desktop \
    cinnamon-session \
    cinnamon-control-center \
    nemo \
    nemo-fileroller

# Small set of general-purpose desktop tools that Mint ships by default
# and Bazzite doesn't, since Rosaline OS is meant for more than gaming.
dnf5 install -y \
    gnome-disk-utility \
    timeshift

# Branding: identify this image as Rosaline OS rather than Bazzite in
# /etc/os-release and friends, without touching the underlying Fedora
# and ublue compatibility fields other tooling relies on.
sed -i "s/^NAME=.*/NAME=\"Rosaline OS\"/" /usr/lib/os-release
sed -i "s/^PRETTY_NAME=.*/PRETTY_NAME=\"Rosaline OS\"/" /usr/lib/os-release
grep -q '^LOGO=' /usr/lib/os-release || echo 'LOGO=rosaline-os' >> /usr/lib/os-release
grep -q '^ANSI_COLOR=' /usr/lib/os-release || echo 'ANSI_COLOR="0;35"' >> /usr/lib/os-release

# Boot splash. The Bazzite base doesn't ship the "script" Plymouth plugin
# our theme uses (ModuleName=script -> "script.so does not exist"), and
# the plain fedora-bootc base used for the smoke flavor (`just smoke`)
# doesn't ship plymouth/dconf/the icon-cache tool at all. Installing is
# a no-op wherever they're already present.
dnf5 install -y plymouth plymouth-plugin-script dconf gtk-update-icon-cache
plymouth-set-default-theme rosaline-os

# Regenerate the initramfs where bootc actually boots it from:
# /usr/lib/modules/<kver>/initramfs.img. `plymouth-set-default-theme -R`
# and a bare `dracut -f` write to /boot instead, which bootc ignores and
# `bootc container lint` flags as nonempty-boot -- the theme would
# silently never appear at boot.
kver="$(basename "$(ls -d /usr/lib/modules/*/ | head -n1)")"
dracut --no-hostonly --kver "$kver" --reproducible --add ostree \
    -f "/usr/lib/modules/${kver}/initramfs.img"
chmod 0600 "/usr/lib/modules/${kver}/initramfs.img"
rm -rf /boot/*

# Wallpaper: system_files/ already dropped the dconf keys and the PNG in
# place; compile the dconf db so the default takes effect, and refresh
# the icon theme cache so desktops pick up the new hicolor icons.
dconf update
gtk-update-icon-cache -f /usr/share/icons/hicolor || true

# Boot-test marker: lets CI/local VM smoke tests (see boot-test.yml,
# `just boot-headless`) detect a successful boot deterministically by
# watching the serial console for a fixed string, instead of guessing at
# getty prompt text.
systemctl enable rosaline-boot-marker.service

echo "Rosaline OS build steps complete."
