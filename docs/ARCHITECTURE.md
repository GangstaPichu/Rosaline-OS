# Architecture

## Why Fedora Atomic instead of Arch or Debian

The four target distros split across two very different foundations:

- **SteamOS** — Arch-based, A/B immutable partitions, gamescope session.
- **Bazzite / Nobara** — Fedora-based. Bazzite is Fedora Atomic
  (`rpm-ostree`/`bootc`, image-based like SteamOS); Nobara is traditional
  Fedora with gaming/driver/codec patches on top.
- **Linux Mint** — Ubuntu/Debian-based, traditional (non-atomic) desktop.

Only one pairing lets Rosaline OS inherit real, currently-maintained
engineering rather than reimplementing it: **Bazzite already *is* a
SteamOS-style Fedora Atomic image that carries Nobara-derived gaming
patches**, because both Bazzite and Nobara track Fedora. Building on top
of Bazzite gets the gamescope session, atomic updates, and driver/codec
work essentially for free.

Arch was ruled out directly by the user. Debian/Ubuntu (to mirror Mint)
would mean rebuilding SteamOS's atomic-update model and Nobara's
driver/gaming patches from scratch on a base that doesn't have Fedora's
`rpm-ostree`/`bootc` tooling or Nobara's patch history — much more work
for a worse result.

That leaves Mint as the odd one out: it contributes a *desktop
environment and philosophy* (Cinnamon, a traditional non-atomic-feeling
daily driver) rather than base OS plumbing. Rosaline OS captures that by
layering an optional Cinnamon session on top of the Bazzite base, not by
switching base distros.

## Why the Nvidia variant specifically

The target hardware is an RTX 4060 Ti. SteamOS has no official Nvidia
support path (Valve tunes it for the Deck's AMD APU), which independently
rules out an Arch/SteamOS-style base for this hardware. Bazzite publishes
an Nvidia variant (`ghcr.io/ublue-os/bazzite-nvidia`) with the proprietary
driver bundled and tested in CI, which is what `Containerfile` builds
from by default via `BASE_IMAGE`/`BASE_TAG` build args.

## Layering model

```
ghcr.io/ublue-os/bazzite-nvidia:stable   (upstream base)
        │
        ├─ system_files/  copied to /            (branding, static config)
        ├─ build_files/build.sh                   (dnf5 installs, config)
        └─ build_files/cleanup.sh                 (trim image size)
        │
        ▼
ghcr.io/gangstapichu/rosaline-os:latest  (published, signed with cosign)
```

Everything Rosaline OS adds is additive on top of the base image: no
upstream Bazzite packages or services are removed, so the gamescope
session, Nvidia driver handling, and atomic update model all keep working
unmodified. Desktop sessions (KDE Plasma from Bazzite, Cinnamon added
here) are chosen at the SDDM login screen.

## Update model

Like Bazzite and SteamOS, updates are whole-image swaps via `bootc`/
`rpm-ostree`, not per-package `dnf upgrade`: `.github/workflows/build.yml`
rebuilds the image (on push, weekly, and on demand), and systems tracking
`ghcr.io/gangstapichu/rosaline-os:latest` pick up the new image on their
next `bootc upgrade` (or via the desktop update notifier that Bazzite
already ships). This keeps the "atomic, reproducible, easy to roll back"
property that both Bazzite and SteamOS rely on.

## Open questions / next steps

- **Branding**: wallpapers, Plymouth boot theme, and a real logo still
  need to be added under `system_files/`.
- **Package list**: `build_files/build.sh` currently adds Cinnamon plus a
  couple of Mint-style utilities (Nemo, Timeshift, GNOME Disks). Further
  Nobara-specific packages not already covered by the Bazzite base
  (extra codecs, specific gaming utilities) should be evaluated and added
  there as needed.
- **Handheld variant**: Bazzite also publishes handheld-focused images;
  a second Containerfile/base-image pairing could produce a
  Deck-like Rosaline OS variant later if wanted.
- **Signing key**: CI currently signs with keyless cosign (Sigstore/OIDC).
  If a dedicated cosign keypair is preferred instead, add
  `cosign.pub`/`cosign.key` (via a repo secret) and update
  `build.yml` accordingly.
