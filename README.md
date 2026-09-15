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

Early scaffold. The image builds and boots on top of Bazzite's Nvidia
variant with a Cinnamon session layered in, and now has a first pass of
branding (icon, wallpaper, boot splash — see `assets/branding/`). Package
selection and further Mint-style polish are still being filled in.

## Repository layout

```
Containerfile           # Image definition (FROM Bazzite, layer build_files/)
build_files/build.sh     # Packages/config installed into the image
build_files/cleanup.sh   # Post-install cleanup
system_files/            # Static files copied verbatim to /
assets/branding/         # Editable logo/wallpaper/boot-theme sources + render.py
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

CI also boot-tests every build automatically — see
`.github/workflows/boot-test.yml` below.

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

- `.github/workflows/build.yml` builds the Containerfile on every push to
  `main`, weekly on a schedule (to pick up upstream Fedora/Bazzite
  security updates), and on pull requests (build-only, no push). Successful
  builds on `main` are pushed to `ghcr.io/gangstapichu/rosaline-os` and
  signed with `cosign` (keyless/Sigstore).
- `.github/workflows/build-iso.yml` builds an installable ISO from the
  published image using `bootc-image-builder` and uploads it as a workflow
  artifact.
- `.github/workflows/boot-test.yml` runs after every successful image
  build: builds a throwaway qcow2 test disk (`vm.toml`) and boots it
  headless in QEMU, failing the job if the image doesn't reach
  `multi-user.target` within 8 minutes. Catches "it builds but doesn't
  boot" regressions automatically. The serial console log is uploaded as
  a workflow artifact either way, for debugging a failure.

## Contributing

Package additions and config changes belong in `build_files/build.sh`.
Static files (branding, wallpapers, config files that don't need shell
logic) belong under `system_files/`, mirroring their destination path.
