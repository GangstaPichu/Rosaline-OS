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
#
# `cinnamon` (not just cinnamon-desktop/cinnamon-session) is the actual
# desktop-environment package -- window manager (Muffin), panel,
# applets, and the /usr/share/xsessions/cinnamon.desktop session file
# itself all live there. cinnamon-desktop is really a shared library
# (like gnome-desktop), and cinnamon-session is just the session
# management *utility* -- neither one is the DE. Found the hard way: a
# real build with only those two installed successfully but had no
# window manager and no session file at all, caught by the check right
# below rather than a VM boot this time.
dnf5 install -y "${dnf5_opts[@]}" \
    cinnamon \
    cinnamon-control-center \
    nemo-fileroller \
    xorg-x11-server-Xorg

# Hard verification, not best-effort: Cinnamon is Rosaline's actual
# differentiator from stock Bazzite, so a build where it can't even
# start has failed at its one job even if everything else succeeds.
# Checks for the exact session file state.conf's [Last]
# Session=cinnamon.desktop actually references, and a working Xorg
# server for it to run on (Fedora 44's `cinnamon` package does also
# ship a Wayland session, cinnamon-wayland.desktop, but state.conf
# explicitly preselects the X11 one, so that's what has to exist).
# xorg-x11-server-Xorg is explicitly listed above rather than assumed
# because Bazzite's own sessions (Plasma, gamescope) are Wayland-first
# -- nothing already on the base image pulls in an actual X server,
# confirmed by a real build where cinnamon.desktop existed but Xorg
# genuinely didn't, caught here rather than a VM boot. (Xorg coexisting
# alongside Wayland Plasma is normal; SDDM already supports mixed
# X11/Wayland sessions from the same greeter.) Fail the build loudly
# rather than discovering any of this three hours into a VM boot test,
# which is how the missing-`cinnamon`-package bug above got found.
if [ ! -f /usr/share/xsessions/cinnamon.desktop ]; then
    echo "FATAL: /usr/share/xsessions/cinnamon.desktop is missing -- Cinnamon won't be selectable at the SDDM greeter at all." >&2
    exit 1
fi
if ! rpm -q xorg-x11-server-Xorg &>/dev/null; then
    echo "FATAL: xorg-x11-server-Xorg isn't installed -- the cinnamon.desktop (X11) session can't actually start without it." >&2
    exit 1
fi

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

# Reskin KDE's upstream "Plasma Setup" (KISS) first-boot wizard -- the
# "Hostname: bazzite" / mascot / landing-wallpaper screens seen on a
# real boot, confirmed to be KDE's own org.kde.plasmasetup, not a
# separate "Bazzite Portal" tool. Most of it already rebrands itself
# for free: the "Enjoy ___!" text reads /etc/os-release NAME= and the
# hostname field reads the real system hostname, both already set
# above. This replaces the two genuinely hardcoded pieces: KDE's own
# Konqi/Katie mascot art on the completion screen, and Bazzite's own
# landing-screen wallpaper. Scoped strictly to files the plasma-setup
# RPM itself owns (rpm -ql), never a broad filesystem search, so this
# can't touch Konqi/Katie art any other KDE app also ships.
# Entirely best-effort: if plasma-setup isn't installed, or none of
# its files match these patterns, this is a silent no-op, not a build
# failure -- the exact installed paths weren't independently
# confirmed against a real package listing.
if rpm -q plasma-setup &>/dev/null; then
    plasma_setup_files="$(rpm -ql plasma-setup)"
    mascot_a=/usr/share/rosaline-os/mascot-a.png
    mascot_b=/usr/share/rosaline-os/mascot-b.png
    wallpaper=/usr/share/backgrounds/rosaline-os/rosaline-default.png

    konqi_matches="$(grep -i 'konqi.*\.png$' <<<"$plasma_setup_files" || true)"
    katie_matches="$(grep -i 'katie.*\.png$' <<<"$plasma_setup_files" || true)"
    wallpaper_matches="$(grep -iE 'bazzite.*convergence.*\.(png|jpe?g)$' <<<"$plasma_setup_files" || true)"

    echo "plasma-setup reskin: konqi matches:"
    echo "${konqi_matches:-  (none)}"
    echo "plasma-setup reskin: katie matches:"
    echo "${katie_matches:-  (none)}"
    echo "plasma-setup reskin: wallpaper matches:"
    echo "${wallpaper_matches:-  (none)}"
    if [ -z "$katie_matches" ] || [ -z "$wallpaper_matches" ]; then
        echo "plasma-setup reskin: diagnostic -- all image files this package owns:"
        grep -iE '\.(png|jpe?g|svg)$' <<<"$plasma_setup_files" || echo "  (none)"
    fi

    while read -r f; do
        [ -f "$f" ] && cp -fv "$mascot_a" "$f"
    done <<<"$konqi_matches"
    while read -r f; do
        [ -f "$f" ] && cp -fv "$mascot_b" "$f"
    done <<<"$katie_matches"
    while read -r f; do
        [ -f "$f" ] && cp -fv "$wallpaper" "$f"
    done <<<"$wallpaper_matches"
else
    echo "plasma-setup not installed; skipping first-boot wizard reskin"
fi

# SDDM login screen background. `theme.conf.user` is the standard,
# update-safe way SDDM themes take a local override (read on top of
# the theme's own theme.conf, never touched by package updates) --
# confirmed via the Breeze SDDM theme's own documented behavior,
# rather than patching any theme's files directly. Applied to every
# installed SDDM theme rather than hardcoding one theme's directory
# name (e.g. "01-breeze-fedora"), since that exact name wasn't
# independently confirmed against Bazzite's actual installed package,
# and there are normally only one or two themes present anyway.
#
# Globs on metadata.desktop, not theme.conf: metadata.desktop is the
# file SDDM actually requires to recognize a directory as a theme at
# all (per SDDM's own theme-discovery mechanism) -- theme.conf itself
# is optional. theme.conf.user doesn't need a sibling theme.conf to
# work.
#
# sddm-breeze is what actually ships /usr/share/sddm/themes/ (the
# Breeze and Breeze-Fedora greeter themes, from the plasma-workspace
# source package) -- confirmed missing entirely from the Bazzite-nvidia
# base image by a real build: /usr/share/sddm/themes/ didn't exist at
# all (not just an empty/unmatched glob), caught by the diagnostic
# `ls` added after the metadata.desktop glob fix still found zero
# themes. Installed explicitly here rather than assumed, same lesson
# as the cinnamon/Xorg fixes above.
dnf5 install -y "${dnf5_opts[@]}" sddm-breeze

login_bg=/usr/share/backgrounds/rosaline-os/rosaline-login.png
shopt -s nullglob
sddm_themes_found=0
for metadata in /usr/share/sddm/themes/*/metadata.desktop; do
    theme_dir="$(dirname "$metadata")"
    echo "SDDM reskin: writing ${theme_dir}/theme.conf.user"
    cat > "${theme_dir}/theme.conf.user" <<-EOF
	[General]
	background=${login_bg}
	type=image
	EOF
    sddm_themes_found=$((sddm_themes_found + 1))
done
shopt -u nullglob
echo "SDDM reskin: ${sddm_themes_found} theme(s) overridden"
if [ "$sddm_themes_found" -eq 0 ]; then
    echo "SDDM reskin: diagnostic -- contents of /usr/share/sddm/themes/ (if it exists):"
    ls -la /usr/share/sddm/themes/ 2>&1 || echo "  (directory doesn't exist)"
fi

# Boot-test marker: lets CI/local VM smoke tests (see boot-test.yml,
# `just boot-headless`) detect a successful boot deterministically by
# watching the serial console for a fixed string, instead of guessing at
# getty prompt text.
systemctl enable rosaline-boot-marker.service

echo "Rosaline OS build steps complete."
