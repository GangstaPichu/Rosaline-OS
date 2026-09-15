# Rosaline OS

Rosaline OS is a Fedora Atomic (`bootc`/`rpm-ostree`) desktop image for
people who want to game *and* use their computer for everything else,
built by combining what already works well in the existing gaming/desktop
Linux distros instead of reinventing it:

| From          | What Rosaline OS keeps |
|---------------|-------------------------|
| **Bazzite**   | Base image, Nvidia driver bundling, gamescope Big Picture session, atomic updates |
| **SteamOS**   | Gamescope session model, A/B-style atomic upgrades (via bootc), Steam-first defaults |
| **Nobara**    | Gaming/codec/driver patches already carried through the Bazzite base |
| **Linux Mint**| An optional Cinnamon desktop session for a traditional, low-friction daily-driver experience |

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for why it's built this
way instead of starting from Arch or Debian.

## Status

Early scaffold. The image itself has been verified to actually build
(`podman build` + `bootc container lint` passing) on top of Bazzite's
Nvidia variant with a Cinnamon session layered in, and has a first pass
of branding (icon, wallpaper, boot splash — see `assets/branding/`).
Converting it to a bootable disk is verified up through the disk write;
an actual QEMU boot is not yet verified — see "Build verification
status" in `docs/ARCHITECTURE.md` for exactly what has and hasn't been
run. Package selection and further Mint-style polish are still being
filled in.

## Repository layout

```
Containerfile           # Image definition (FROM Bazzite, layer build_files/)
build_files/build.sh     # Packages/config installed into the image
build_files/cleanup.sh   # Post-install cleanup
system_files/            # Static files copied verbatim to /
assets/branding/         # Editable logo/wallpaper/boot-theme sources + render.py
cosign.pub                # Rosaline OS's public signing key
security/                 # Vendored trust anchors + signing docs (see Security below)
iso.toml                 # bootc-image-builder config for the real installer ISO
vm.toml                   # bootc-image-builder config for throwaway *test* VM disks
justfile                 # Local build/lint/boot commands (podman + just [+ qemu])
.github/workflows/       # CI: build+push OCI image, build ISO, boot-test in QEMU
```

## Building locally

Requires `podman` and [`just`](https://github.com/casey/just):

```sh
just build          # build the OCI image locally
just lint            # lint the Containerfile
```

## Testing locally in a VM

Run this on your own machine (needs a local display for `boot`, and
ideally `/dev/kvm` for speed) — not inside a headless container/CI
environment.

Prerequisites: `podman`, `just`, and `qemu-system-x86` (e.g.
`sudo dnf install qemu-system-x86` on Fedora/Bazzite, or
`sudo apt install qemu-system-x86` on Debian/Ubuntu). For KVM speed,
make sure `/dev/kvm` exists and your user can access it
(`sudo usermod -aG kvm $USER`, then re-login).

```sh
just build-vm-image   # build the image, then turn it into a bootable qcow2
just boot             # boot it in an interactive QEMU window
# or, for a quick heads-down check with no GUI:
just boot-headless
just ssh              # in another terminal, once it's up
```

`vm.toml` bakes a throwaway `rosaline`/`rosaline` account into the test
disk purely so you can log in — it's never used for the real installer
ISO (`iso.toml`), and the disk it produces should never be shipped or
reused for anything real.

### Smoke flavor (small machines, sandboxes, quick iteration)

The real image sits on a 13 GB Bazzite base. `just smoke` builds the
same `build_files/` + `system_files/` on a plain 2 GB `fedora-bootc`
base instead, converts it to a disk, boots it headless, and checks for
the boot marker — end to end, in one command. It exercises everything
Rosaline itself adds (package list, Plymouth theme + initramfs, dconf,
boot marker) but not Bazzite's Nvidia/gamescope/KDE stack, which we
don't touch anyway.

If your kernel can't create loop partition nodes or mount vfat (some
container sandboxes), `just smoke-sandbox` uses
`scripts/sandbox/build-disk.sh` to work around that with a BIOS-only
disk — good for `boot-check`, never for a real install.

`just boot-check` is the non-interactive verdict for any built disk:
exit 0 if the VM reaches `multi-user.target`, serial console in
`serial.log`.

### CI

The workflows in `.github/workflows/` are manual-only
(`workflow_dispatch`): this repo is private on GitHub's free tier, where
Actions minutes are capped, and one image build would burn a large
chunk of them. Everything they do is available locally through the
justfile. Making the repo public would give unlimited Actions minutes
if automatic builds are ever wanted.

## Installing / switching to Rosaline OS

Rosaline OS is distributed as an OCI container image. On any `bootc`-based
system (Fedora Atomic, Bazzite, etc.) you can switch to it directly:

```sh
sudo bootc switch ghcr.io/gangstapichu/rosaline-os:latest
```

Or download an installer ISO from the
[latest "Build Rosaline OS ISO" workflow run](../../actions/workflows/build-iso.yml)
and install fresh.

## CI/CD

All manual-only (see "CI" above for why):

- `.github/workflows/build.yml` verifies the Bazzite base image's
  signature, builds the Containerfile, pushes the result to
  `ghcr.io/gangstapichu/rosaline-os`, and signs it with `cosign` using a
  static key (see "Security" below). Needs the `SIGNING_SECRET` and
  `SIGNING_SECRET_PASSWORD` repository secrets to be set.
- `.github/workflows/build-iso.yml` builds an installable ISO from the
  published image using `bootc-image-builder` and uploads it as a workflow
  artifact.
- `.github/workflows/boot-test.yml` builds a throwaway qcow2 test disk
  (`vm.toml`) from the published image and runs `scripts/boot-check.sh`
  on it — the same check as `just boot-check` — uploading the serial
  console log as an artifact either way.

All third-party Actions used in these workflows are pinned to a commit
SHA (not a mutable version tag), fetched fresh from each action's repo
rather than trusted from memory — see the `# vX.Y.Z` comment on each
`uses:` line for what it resolves to.

## Security

- **Image signing**: every image pushed to `ghcr.io/gangstapichu/rosaline-os`
  is signed with `cosign` using a static keypair (`cosign.pub` at the repo
  root; the private half lives only in GitHub Actions secrets). This is
  the same mechanism `ublue-os/bazzite` itself uses for its published
  images — verified directly against a real `bazzite-nvidia` image before
  relying on it, see `security/README.md`.
- **Base image verification**: `build.yml` runs `cosign verify` against
  `ghcr.io/ublue-os/bazzite-nvidia` (using their real, vendored public
  key) *before* building — a compromised or substituted base image fails
  the build instead of silently becoming part of Rosaline OS.
- **Client-side enforcement**: the image ships its own
  `/etc/containers/policy.json` + `/etc/containers/registries.d/`, so
  once you're running Rosaline OS, `bootc upgrade` / `podman pull`
  cryptographically verify every future update against
  `system_files/usr/share/rosaline-os/cosign.pub` — pulling a tampered
  or unsigned image fails outright. This is stricter than upstream:
  Bazzite signs its images but doesn't actually ship a policy that
  enforces verification on the client. The policy/registries.d
  mechanism was tested end-to-end against a local registry (correct
  signature accepted, wrong key and unsigned image both cryptographically
  rejected) before being shipped — see `security/README.md`.
- **Known limitation**: cosign signatures only assert repository
  identity, not the specific tag (a `containers/image` limitation, not
  something specific to this setup) — see `security/README.md`.
- **Verify by hand**:
  `cosign verify --key cosign.pub --new-bundle-format=false ghcr.io/gangstapichu/rosaline-os:latest`

Setting up the two required secrets (only needed once, by whoever
maintains signing):

```sh
gh secret set SIGNING_SECRET --repo gangstapichu/rosaline-os < /path/to/cosign.key
gh secret set SIGNING_SECRET_PASSWORD --repo gangstapichu/rosaline-os
```

(or paste them into **Settings → Secrets and variables → Actions** in
the GitHub web UI). The keypair matching the committed `cosign.pub` was
generated in this session and sent to you directly (never committed to
the repo) — see the chat for the private key file and password. If
they're ever lost, rotate to a new keypair per `security/README.md`
instead of trying to recover them.

## Contributing

Package additions and config changes belong in `build_files/build.sh`.
Static files (branding, wallpapers, config files that don't need shell
logic) belong under `system_files/`, mirroring their destination path.
