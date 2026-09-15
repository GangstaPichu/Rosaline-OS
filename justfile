## Rosaline OS local dev commands. Requires podman.

image_name := "rosaline-os"
default_tag := "latest"

# Build the image locally
build tag=default_tag:
    podman build -t {{image_name}}:{{tag}} -f Containerfile .

# Build and boot the image in a disposable VM with bootc (requires qemu)
run-vm tag=default_tag: (build tag)
    podman run --rm --privileged \
        -v /var/lib/containers/storage:/var/lib/containers/storage \
        quay.io/centos-bootc/bootc-image-builder:latest \
        --type qcow2 \
        localhost/{{image_name}}:{{tag}}

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
