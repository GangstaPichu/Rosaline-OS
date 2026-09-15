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
iso.toml                 # bootc-image-builder config for ISO installer output
justfile                 # Local build/lint/rebase commands (podman + just)
.github/workflows/       # CI: build+push OCI image, build installer ISO
```

## Building locally

Requires `podman` and [`just`](https://github.com/casey/just):

```sh
just build          # build the OCI image locally
just lint           # lint the Containerfile
just run-vm         # build a bootable qcow2 and boot it in a VM
```

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

## Contributing

Package additions and config changes belong in `build_files/build.sh`.
Static files (branding, wallpapers, config files that don't need shell
logic) belong under `system_files/`, mirroring their destination path.
