## Rosaline OS local dev commands.
## `build`/`build-vm-image`/`lint` need podman. `boot`/`boot-headless`/`ssh`
## additionally need qemu-system-x86 (and ideally /dev/kvm) on the machine
## you run `just` on -- see "Testing locally" in README.md.

image_name := "rosaline-os"
default_tag := "latest"
vm_ram := "8G"
vm_cpus := "4"
ssh_port := "2222"
disk := "output/qcow2/disk.qcow2"

# Build the image locally
build tag=default_tag:
    podman build -t {{image_name}}:{{tag}} -f Containerfile .

# Turn a locally built image into a bootable qcow2 test disk (throwaway
# rosaline/rosaline dev account baked in via vm.toml -- see that file).
# --rootfs ext4 is required: the Bazzite base doesn't declare a default
# root filesystem, and bootc-image-builder fails with "missing required
# info: DefaultRootFs" without it (confirmed by actually running this).
build-vm-image tag=default_tag: (build tag)
    mkdir -p output
    sudo podman run --rm --privileged --pull=newer \
        --security-opt label=type:unconfined_t \
        -v ./output:/output \
        -v ./vm.toml:/config.toml:ro \
        -v /var/lib/containers/storage:/var/lib/containers/storage \
        quay.io/centos-bootc/bootc-image-builder:latest \
        --type qcow2 \
        --rootfs ext4 \
        --config /config.toml \
        localhost/{{image_name}}:{{tag}}

# Boot the test disk in an interactive QEMU window. Run `build-vm-image`
# first. Needs a local display -- this is for your own desktop, not a
# headless box. Uses KVM automatically if /dev/kvm is present.
boot:
    #!/usr/bin/env bash
    set -euo pipefail
    kvm_flags=()
    if [ -e /dev/kvm ]; then
        kvm_flags=(-enable-kvm -cpu host)
    else
        echo "WARNING: /dev/kvm not found -- falling back to slow software emulation" >&2
    fi
    qemu-system-x86_64 "${kvm_flags[@]}" \
        -m {{vm_ram}} -smp {{vm_cpus}} \
        -drive file={{disk}},if=virtio,format=qcow2 \
        -netdev user,id=n0,hostfwd=tcp::{{ssh_port}}-:22 -device virtio-net-pci,netdev=n0 \
        -vga virtio -display gtk

# Same as `boot` but no GUI window -- serial console only. Good for a
# quick "does it actually boot" check, or on a machine with no display.
boot-headless:
    #!/usr/bin/env bash
    set -euo pipefail
    kvm_flags=()
    if [ -e /dev/kvm ]; then
        kvm_flags=(-enable-kvm -cpu host)
    else
        echo "WARNING: /dev/kvm not found -- falling back to slow software emulation" >&2
    fi
    qemu-system-x86_64 "${kvm_flags[@]}" \
        -m {{vm_ram}} -smp {{vm_cpus}} \
        -drive file={{disk}},if=virtio,format=qcow2 \
        -netdev user,id=n0,hostfwd=tcp::{{ssh_port}}-:22 -device virtio-net-pci,netdev=n0 \
        -display none -serial mon:stdio

# SSH into a running test VM (the throwaway account from vm.toml)
ssh:
    ssh -p {{ssh_port}} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null rosaline@localhost

# Lint the Containerfile with hadolint
lint:
    podman run --rm -v "$PWD":/work:ro -w /work docker.io/hadolint/hadolint hadolint Containerfile

# Rebase a running Bazzite/Fedora Atomic system onto a locally built image
# for testing (destructive to the running system's image state on reboot).
rebase-local tag=default_tag:
    sudo bootc switch --transport containers-storage {{image_name}}:{{tag}}

# Rebase a running system onto the published image from GHCR
rebase-remote owner="gangstapichu":
    sudo bootc switch ghcr.io/{{owner}}/{{image_name}}:latest
