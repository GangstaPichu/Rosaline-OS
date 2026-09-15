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

## Build verification status

The container image itself has actually been built end-to-end and
verified — not just reviewed — including running `podman build` for
real against `ghcr.io/ublue-os/bazzite-nvidia:stable` and confirming
`bootc container lint` passes (10 checks passed, 3 cosmetic warnings
about non-empty `/boot`/`/run`/`/var` content, which is normal/expected
for an image that just ran a Plymouth initramfs rebuild and dnf5).
That run caught and fixed two real bugs that static review had missed:

1. `plymouth-set-default-theme -R rosaline-os` failed with
   `script.so does not exist` — the Bazzite base doesn't install the
   `plymouth-plugin-script` package our `ModuleName=script` theme
   depends on. Fixed by installing it in `build_files/build.sh` before
   setting the theme.
2. `build_files/cleanup.sh` ran `rm -rf /tmp/*`, but `/tmp/build_files`
   is a live bind mount of the *host* `build_files/` directory for the
   duration of that `RUN` step (see the Containerfile). `rm -rf`
   recursed into it and deleted `build.sh`/`cleanup.sh` themselves
   before failing to remove the (busy) mountpoint. Fixed by excluding
   that one path from the cleanup.

A third bug came out of the follow-up: `bootc container lint` flagged a
non-empty `/boot`, because `plymouth-set-default-theme -R` regenerates
the initramfs into `/boot`, which bootc ignores — the theme would never
have appeared at boot. `build.sh` now runs `dracut` against
`/usr/lib/modules/<kver>/initramfs.img` and clears `/boot`; the
resulting initramfs was inspected with `lsinitrd` and contains the
theme, `script.so`, and a `plymouthd.conf` pointing at it.

**The smoke flavor has booted, end to end.** `just smoke` builds the
same `build_files/` + `system_files/` on `quay.io/fedora/fedora-bootc:44`
(2 GB instead of 13 GB), converts it to a qcow2, and boots it headless.
That was run for real in the development sandbox — under pure TCG
software emulation, no KVM — and the serial console showed
`Booting initrd of Rosaline OS`, `Welcome to Rosaline OS!`,
`plymouth-start.service` starting, and the `ROSALINE-OS-BOOT-OK`
marker from `rosaline-boot-marker.service` about 90 guest-seconds in.
So the package list resolves on Fedora 44, the build scripts work on a
base that isn't Bazzite, the initramfs/Plymouth wiring is right, the
dconf and marker units behave, and `bootc-image-builder` needs
`--rootfs ext4` (the base declares no default; now passed everywhere).

Two things that flavor cannot show: what the Plymouth theme *looks*
like (serial console only), and anything in Bazzite's own stack
(Nvidia driver, gamescope, KDE) — which Rosaline doesn't modify.

The sandbox needed workarounds that are now checked in as
`scripts/sandbox/build-disk.sh` (`just smoke-sandbox`): its kernel has
no partition-table parsers (loop devices never get `pN` nodes; fixed by
shimming osbuild's loopback device to call `partx -a`) and no vfat (the
EFI partition can't be mounted; worked around by building a BIOS-only
disk with the EFI bootloader component removed and partition 2 not
typed as an ESP). Those are properties of that environment, not of the
image; on a normal machine `just smoke` / `just build-vm-image` don't
need them.

**Still unverified:** converting the full Bazzite-based image to a disk
and booting it. Its container build is verified (above), but the
sandbox's fixed ~30 GB disk allowance can't hold a 13 GB base plus a
comparably sized disk image at once — it ran out of space partway
through the ostree checkout. That step needs a machine with more free
disk; the same `just build-vm-image && just boot-check` applies there.

## Open questions / next steps

- **Branding**: done for a first pass — logo/icon, wallpaper, and a
  Plymouth boot theme live in `system_files/` (sources + regeneration
  script in `assets/branding/`). It doesn't implement a LUKS password
  prompt — see `assets/branding/README.md` and the comment at the top of
  `rosaline-os.script`.
- **VM testing**: see "Build verification status" above — the smoke
  flavor is verified end to end; the Bazzite-based image is verified
  through the container build and needs a machine with more disk for
  `just build-vm-image && just boot-check`. CI (`boot-test.yml`) can
  now do this too since the repo went public (unlimited Actions
  minutes) — still `workflow_dispatch`-only by choice, not by quota, so
  the justfile stays the primary path for day-to-day iteration.
- **Package list**: `build_files/build.sh` currently adds Cinnamon plus a
  couple of Mint-style utilities (Nemo, Timeshift, GNOME Disks). Further
  Nobara-specific packages not already covered by the Bazzite base
  (extra codecs, specific gaming utilities) should be evaluated and added
  there as needed.
- **Handheld variant**: Bazzite also publishes handheld-focused images;
  a second Containerfile/base-image pairing could produce a
  Deck-like Rosaline OS variant later if wanted.
- **Security**: see "Security architecture" below — image signing, base
  verification, and client-side enforcement are done and confirmed with
  a real green CI run (not just the sandbox); pending is actually
  rotating in a production keypair if the one generated during
  development should be replaced, and deciding whether to also pin
  `bootc-image-builder`/`fedora-bootc`/`registry:2` OCI *images* by
  digest in the workflows and justfile (currently pulled by mutable tag
  — lower risk than the GitHub Actions themselves since they're not
  handed secrets or write access, but not nothing).

## Security architecture

Everything below was checked by actually running it against real
artifacts in the development sandbox, not just written to spec —
`security/README.md` has the how.

**Signing.** Images are signed with a static cosign keypair (the
`ghcr.io/ublue-os/bazzite-nvidia` image we build from is a real,
working example of this exact approach: its own signature was decoded
down to the raw Rekor transparency-log entry and confirmed to be a
plain-key signature using precisely the key published at
`ublue-os/bazzite`'s `cosign.pub`, which is also vendored here as
`security/ublue-bazzite-cosign.pub`). `build.yml` verifies the base
image against that key before building (`cosign verify --key
security/ublue-bazzite-cosign.pub --new-bundle-format=false`), and
signs the finished image with Rosaline OS's own key afterward
(`secrets.SIGNING_SECRET`).

**Confirmed in real CI**, not just the sandbox: `build.yml` run
[#8](https://github.com/GangstaPichu/Rosaline-OS/actions/runs/35012539566)
went green end to end (base-image verify → build → push → sign), and the
result was independently checked outside that run too —
`cosign verify --key cosign.pub --new-bundle-format=false
ghcr.io/gangstapichu/rosaline-os:latest` against the real published image
reports "The signatures were verified against the specified public key",
and `skopeo inspect --no-creds` confirms the image pulls without
credentials, which a fresh `bootc switch` needs. Getting here surfaced
two more real bugs neither local testing nor review had caught:

1. Every run of this workflow ever, across five unrelated commits, had
   failed in 4-5 seconds with no logs. Cause: the repo was private on
   GitHub's Free plan, which caps included Actions minutes with a $0
   default spending limit for overage — every run failed before a
   runner even started. Fixed by making the repo public (unlimited
   Actions minutes; no code change).
2. The first real run then got through base verification and the build,
   but failed pushing: `Invalid image name
   ghcr.io/GangstaPichu/rosaline-os:latest, unknown transport
   ghcr.io/GangstaPichu/rosaline-os`. `github.repository_owner` is
   `GangstaPichu` (mixed case), and GHCR/OCI references must be
   all-lowercase — reproduced locally against the same podman version
   to confirm before fixing. GitHub Actions expressions have no
   built-in lowercase function, so all three workflows now compute
   `IMAGE_REGISTRY` in a shell step (`tr '[:upper:]' '[:lower:]'`) and
   export it via `$GITHUB_ENV` instead of interpolating
   `${{ github.repository_owner }}` directly.

**Client-side enforcement.** `system_files/etc/containers/policy.json`
and `system_files/etc/containers/registries.d/rosaline-os.yaml` scope a
`sigstoreSigned` requirement to `ghcr.io/gangstapichu/rosaline-os`
specifically, leaving the rest of the system's default policy
(`insecureAcceptAnything`, matching stock Fedora) untouched — so
Flatpak/Distrobox/other registries keep working exactly as before, but
`bootc upgrade` on a running Rosaline OS system now actually verifies
signatures, which Bazzite itself doesn't enforce even though it signs.
This was validated against a throwaway local registry with the same
`policy.json`/`registries.d` mechanics (different scope name only):
`skopeo copy` succeeded for a correctly-signed image, and failed with
`cryptographic signature verification failed` for a wrong key and
`A signature was required, but no signature exists` for a genuinely
unsigned image at a different digest. (An earlier attempt using
`skopeo inspect` for this test was a false positive in both directions
— `inspect` doesn't consult `policy.json` at all; `copy`, which is what
`podman pull`/`bootc` actually use, does.)

Per `man containers-policy.json`: cosign-created signatures only
contain repository identity, so `signedIdentity` must be
`matchRepository` — the stricter default
(`matchRepoDigestOrExact`) rejects every cosign signature outright.
This means verification confirms an image came from our repository and
was signed with our key, not that you got the exact tag you asked for
over a substitution of another signed tag from the same repository —
an inherent limit of cosign's identity model, not something this setup
could tighten further.

**Supply chain.** Every third-party GitHub Action in `.github/workflows/`
is pinned to a commit SHA rather than a mutable tag (`v4`, `@main`,
etc. can be repointed by the action's maintainer, or its account, to
different code without any change on our end). SHAs were fetched fresh
via `git ls-remote --tags` against each action's real repository for
this work, matching the *currently-used major version* rather than
jumping to a newer major that hasn't been exercised here (e.g. pinned
`actions/checkout` to the latest `v4.x`, not `v7`). One of these,
`sigstore/cosign-installer`, could be cross-checked against a real,
independent pin: `ublue-os/bazzite`'s own `build.yml` pins the exact
same commit for the same tag (`6f9f177…` for `v4.1.2`).
