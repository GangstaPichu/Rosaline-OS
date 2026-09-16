#!/usr/bin/env bash
#
# Runs inside the image build (see Containerfile). Layers Rosaline OS's
# additions onto the Bazzite base: a Cinnamon desktop option (Mint-style
# daily-driver session), OS branding, and a couple of quality-of-life
# packages that aren't already part of Bazzite/Nobara's gaming stack.
set -ouex pipefail

# dnf5 defaults to 3 parallel package downloads (max allowed is 20); the
# CI runner's network can comfortably do more than that, and none of
# this depends on download order.
dnf5_opts=(--setopt=max_parallel_downloads=10)

# Cinnamon gives people the option of a traditional, low-friction desktop
# (a la Linux Mint) alongside Bazzite's existing KDE Plasma / gamescope
# sessions -- SDDM lets users pick a session at login, nothing here removes
# the gaming-focused defaults.
dnf5 install -y "${dnf5_opts[@]}" \
    cinnamon-desktop \
    cinnamon-session \
    cinnamon-control-center \
    nemo \
    nemo-fileroller

# Small set of general-purpose desktop tools that Mint ships by default
# and Bazzite doesn't, since Rosaline OS is meant for more than gaming.
dnf5 install -y "${dnf5_opts[@]}" \
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
dnf5 install -y "${dnf5_opts[@]}" plymouth plymouth-plugin-script dconf gtk-update-icon-cache
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

# system_files/var/lib/sddm/state.conf preselects Cinnamon in the SDDM
# greeter (see that file for why it's [Last], not [Autologin]). SDDM's
# own package owns that directory; match its ownership so the daemon
# can still rewrite the file on a real login. Non-fatal if the sddm
# user somehow isn't present -- root-owned still works, just can't be
# updated by an unprivileged daemon process.
chown -R sddm:sddm /var/lib/sddm 2>/dev/null || true

# Bazzite's own bazzite-autologin.service runs on every boot and writes
# real [Autologin] config to /etc/sddm.conf.d/zz-*.conf -- the "zz-"
# prefix makes it win over anything else, including the state.conf
# preselection above, so the greeter never even appears and it logs
# straight into plasma.desktop (hardcoded; it has no idea Cinnamon
# exists). That's the right behavior for Bazzite's own gaming/desktop-
# mode switching on handhelds, but wrong for Rosaline OS, which wants a
# normal login screen with Cinnamon preselected, not skipped entirely.
# Confirmed directly against a real boot: no login screen at all,
# straight into Plasma's first-run wizard, before this was added.
systemctl mask bazzite-autologin.service

# Boot-test marker: lets CI/local VM smoke tests (see boot-test.yml,
# `just boot-headless`) detect a successful boot deterministically by
# watching the serial console for a fixed string, instead of guessing at
# getty prompt text.
systemctl enable rosaline-boot-marker.service

echo "Rosaline OS build steps complete."
