#!/usr/bin/env bash
#
# Boots a qcow2 headless in QEMU and waits for the marker that
# rosaline-boot-marker.service prints to the serial console once
# multi-user.target is reached. Exit 0 if seen, 1 on timeout or if QEMU
# exits first. Used by `just boot-check` and boot-test.yml.
#
# Usage: scripts/boot-check.sh [disk.qcow2] [timeout-seconds]
set -euo pipefail

disk="${1:-output/qcow2/disk.qcow2}"
timeout_s="${2:-${BOOT_TIMEOUT_SECONDS:-900}}"
marker="${BOOT_MARKER:-ROSALINE-OS-BOOT-OK}"
log="${SERIAL_LOG:-serial.log}"
ram="${VM_RAM:-4G}"
cpus="${VM_CPUS:-4}"

# -cpu max under TCG exposes every feature the emulator supports, which
# Fedora's x86-64-v2+ kernel baseline needs; the default qemu64 CPU is
# too old to boot it.
accel=(-cpu max)
if [ -e /dev/kvm ] && [ -w /dev/kvm ]; then
    accel=(-enable-kvm -cpu host)
else
    echo "boot-check: no usable /dev/kvm, using TCG software emulation (slow)" >&2
fi

rm -f "$log"
qemu-system-x86_64 "${accel[@]}" \
    -m "$ram" -smp "$cpus" \
    -drive file="$disk",if=virtio,format=qcow2 \
    -netdev user,id=n0 -device virtio-net-pci,netdev=n0 \
    -display none -serial "file:$log" -no-reboot &
qemu_pid=$!
trap 'kill "$qemu_pid" 2>/dev/null || true' EXIT

deadline=$(( $(date +%s) + timeout_s ))
while [ "$(date +%s)" -lt "$deadline" ]; do
    if grep -q "$marker" "$log" 2>/dev/null; then
        echo "boot-check: marker '$marker' seen -- image boots to multi-user.target"
        exit 0
    fi
    if ! kill -0 "$qemu_pid" 2>/dev/null; then
        echo "boot-check: QEMU exited before the marker appeared; see $log" >&2
        exit 1
    fi
    sleep 5
done

echo "boot-check: marker not seen within ${timeout_s}s; see $log" >&2
exit 1
