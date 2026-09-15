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

# Boot splash: install as the default Plymouth theme and rebuild the
# initramfs (-R) so it's actually picked up.
plymouth-set-default-theme -R rosaline-os

# Wallpaper: system_files/ already dropped the dconf keys and the PNG in
# place; compile the dconf db so the default takes effect, and refresh
# the icon theme cache so desktops pick up the new hicolor icons.
dconf update
gtk-update-icon-cache -f /usr/share/icons/hicolor || true

echo "Rosaline OS build steps complete."
