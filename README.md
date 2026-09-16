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
CI now builds, verifies, pushes, and signs it for real — see
`ghcr.io/gangstapichu/rosaline-os` and "Security" below. Converting it
to a bootable disk is verified up through the disk write; an actual
QEMU boot is not yet verified — see "Build verification status" in
`docs/ARCHITECTURE.md` for exactly what has and hasn't been run.
Package selection and further Mint-style polish are still being
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
(`workflow_dispatch`) by choice, not necessity — the repo is public, so
Actions minutes are unlimited, but nothing should fire without someone
asking for it. Everything they do is also available locally through the
justfile.

### Testing on Windows without Hyper-V

If WSL2 isn't an option (it's built on Hyper-V, so if Hyper-V itself is
the problem — e.g. it's been causing bluescreens with other
software/games — WSL2 will hit the same issue), let CI do the only step
that actually needs real Linux, and just boot the result locally:

1. **Actions tab → "Build Rosaline OS image" → Run workflow.** Rebuilds
   and pushes the image, then — as its last step — dispatches "Build
   downloadable test disk" itself, so one click starts both instead of
   having to babysit the first and manually trigger the second (that
   second step couldn't be a normal `on: workflow_run` trigger, since
   those only ever look at the workflow file on the *default* branch,
   never the branch actually running — this repo dispatches it
   explicitly instead so it works from any branch). If you only need a
   disk from what's already published and don't need a rebuild, you can
   still run **"Build downloadable test disk"** on its own — it takes a
   `format` input (`vmdk` or `qcow2`, see below), defaulting to `vmdk`.
2. **Wait for both to finish**, then download the
   `rosaline-os-test-disk-vmdk` (or `-qcow2`) artifact from the second
   workflow's run. It pulls the published image and converts it
   directly with `bootc-image-builder` (needs privileged containers and
   loop devices — real Linux, which is why this runs in CI rather than
   on Windows) into whichever format you asked for, then uploads it
   uncompressed. It's a multi-GB download either way; measured on a
   real run, gzip only shaved 1.2% off this specific file (it's already
   too dense — RPM payloads, binaries — to compress well), so there's no
   real size upside to compressing it, only slower CI and an extra
   decompression step for you.
3. **Download the artifact.** It arrives as a `.zip` (GitHub wraps every
   artifact that way) — extract it and you've got the raw `.vmdk` or
   `.qcow2` directly, no further decompression needed.

From here, pick one:

#### VirtualBox or VMware (recommended — hardware-accelerated)

With Hyper-V off (and **Windows Security → Device security → Core
isolation → Memory integrity** also off — if that's on, Windows runs
the Hyper-V hypervisor invisibly underneath regardless of the Hyper-V
Windows feature's own on/off switch, and both apps below silently fall
back to a slow emulated mode), VirtualBox and VMware Workstation Pro
(free for personal use) both drive VT-x directly instead of emulating
it, which is the difference between "sluggish" and "normal speed."

Use the `vmdk` format from step 2 above — no conversion needed, it's a
disk format both tools already understand. Create a new VM pointed at
that `disk.vmdk`, give it EFI/UEFI firmware (both bootc's qcow2 and
vmdk outputs are GPT+ESP, not legacy BIOS), 8GB+ RAM, and as many
cores as you're comfortable giving it. Log in with the throwaway
`rosaline`/`rosaline` account (from `vm.toml` — never used on a real
install).

If you already have an old `.qcow2` around and don't want to
re-download, `qemu-img convert -O vmdk disk.qcow2 disk.vmdk` (from a
QEMU install) does the same conversion locally — just remember it's a
one-time snapshot, not a link, so re-run it after every new qcow2.

#### Plain QEMU (no extra software, but slower)

If you'd rather not install another hypervisor, request `qcow2` from
step 1/2 above and boot it in QEMU's own software emulation — no
`-accel whpx`, no `-enable-kvm`, nothing that touches VT-x/AMD-V or the
hypervisor layer at all, so it can't trigger whatever makes Hyper-V
unstable on that machine, but noticeably slower (expect it to feel
sluggish, especially at the boot splash):
```powershell
qemu-system-x86_64.exe -accel tcg -m 8G -smp 8 `
  -drive file=disk.qcow2,if=virtio,format=qcow2,cache=writeback `
  -device virtio-vga -usb -device usb-tablet -device virtio-rng-pci `
  -netdev user,id=n0,hostfwd=tcp::2222-:22 -device virtio-net-pci,netdev=n0
```
`-smp` and `cache=writeback` are worth tuning to your actual machine —
TCG's multi-threaded mode runs each virtual CPU on its own host
thread, so a `-smp` closer to your real core/thread count lets more of
the guest's own parallel boot work (systemd starting units
concurrently, desktop session startup) actually happen at once instead
of serializing; `cache=writeback` speeds up disk-heavy moments like the
initial boot and is safe here since this disk is disposable.
`virtio-vga` is the proper paravirtual display for a Linux guest;
`usb-tablet` gives the mouse absolute positioning so the window stops
grabbing your cursor; `virtio-rng-pci` feeds the guest entropy so early
boot doesn't stall waiting for it. None of this is a magic multiplier
— a lot of boot is inherently single-threaded, and TCG's
per-instruction translation overhead doesn't go away — but it helps.
Same login as above.

Either way, this disk is for boot-testing only, same as `vm.toml`'s
local equivalent — never install from it for real.

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
- `.github/workflows/build-test-disk.yml` does the same disk conversion
  but uploads the (gzipped) qcow2 itself as a downloadable artifact
  instead of boot-checking it — see "Testing on Windows without
  Hyper-V" above.

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
