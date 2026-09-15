#!/usr/bin/env bash
#
# Build a bootable qcow2 from a local image in environments whose kernel
# can't do what bootc-image-builder normally needs: no partition-table
# parsers (so loop devices never get /dev/loopNpM nodes) and no vfat (so
# the EFI partition can't be mounted). Seen in container sandboxes that
# run on minimal Firecracker-style kernels. On a normal machine use
# `just build-vm-image` instead -- this is a workaround, not the product.
#
# The result is a BIOS-only disk: the EFI bootloader component is
# skipped and partition 2 is not marked as an ESP. That's fine for a
# QEMU/SeaBIOS smoke test (`just boot-check`) and useless for a real
# install; never ship it.
#
# Usage: scripts/sandbox/build-disk.sh <image tag>    e.g. smoke
set -euo pipefail

tag="${1:?usage: $0 <image tag>}"
image="localhost/rosaline-os:${tag}"
bib="quay.io/centos-bootc/bootc-image-builder:latest"
root="$(cd "$(dirname "$0")/../.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
cd "$root"

# 1. osbuild's loopback device globs /dev/loopNp* exactly once, right
#    after attaching with partscan. Without a kernel partition parser
#    those nodes never appear, so shim it to add them via partx (the
#    BLKPG ioctl, which works without a parser) before the glob.
podman run --rm --entrypoint cat "$bib" \
    /usr/lib/osbuild/devices/org.osbuild.loopback > "$work/loopback"
python3 - "$work/loopback" <<'EOF'
import sys
p = sys.argv[1]
s = open(p).read()
anchor = "            if partscan:\n"
assert s.count(anchor) == 1, "osbuild loopback device changed; shim anchor not found"
s = s.replace(anchor, anchor
    + '                import subprocess\n'
    + '                subprocess.run(["partx", "-a", f"/dev/{self.lo.devname}"],\n'
    + '                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)\n')
open(p, "w").write(s)
EOF
chmod 755 "$work/loopback"

# 2. bootupd installs every bootloader component the image carries, and
#    the EFI one needs a mounted vfat ESP. Derive a throwaway image
#    without the EFI component so only BIOS grub gets installed.
printf 'FROM %s\nRUN rm -f /usr/lib/bootupd/updates/EFI.json\n' "$image" \
    | podman build --network=host -q -t "rosaline-os:${tag}-bios" -f - . >/dev/null

# 3. Generate bib's manifest for that image, then drop every mount of
#    the EFI partition and stop marking it as an ESP, so neither osbuild
#    nor bootupd goes looking for one.
podman run --rm --privileged --security-opt label=type:unconfined_t \
    -v ./vm.toml:/config.toml:ro \
    -v /var/lib/containers/storage:/var/lib/containers/storage \
    "$bib" manifest --type qcow2 --rootfs ext4 --config /config.toml \
    "localhost/rosaline-os:${tag}-bios" > "$work/manifest.json"
python3 - "$work/manifest.json" <<'EOF'
import json, sys
p = sys.argv[1]
m = json.load(open(p))
ESP = "C12A7328-F81F-11D2-BA4B-00A0C93EC93B"
LINUX = "0FC63DAF-8483-4772-8E79-3D69D8477DE4"
for pipeline in m["pipelines"]:
    for stage in pipeline.get("stages", []):
        if "mounts" in stage:
            stage["mounts"] = [mm for mm in stage["mounts"] if mm["name"] != "boot-efi"]
        if stage["type"] == "org.osbuild.sfdisk":
            for part in stage["options"]["partitions"]:
                if part.get("type", "").upper() == ESP:
                    part["type"] = LINUX
json.dump(m, open(p, "w"), indent=1)
EOF

# 4. Run osbuild directly (what bib would have done) with the shim, the
#    patched manifest, and the host's /dev so BLKPG-created partition
#    nodes are visible inside the container.
rm -rf output && mkdir -p output
podman run --rm --privileged --security-opt label=type:unconfined_t \
    -v /dev:/dev \
    -v "$work/loopback:/usr/lib/osbuild/devices/org.osbuild.loopback:ro" \
    -v "$work/manifest.json:/manifest.json:ro" \
    -v ./output:/output \
    -v /var/lib/containers/storage:/var/lib/containers/storage \
    --entrypoint bash "$bib" -c \
    'mkdir -p /store && cd /output && exec osbuild --store /store --output-directory /output --export qcow2 /manifest.json'

ls -la output/qcow2/disk.qcow2
