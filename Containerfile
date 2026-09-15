# Rosaline OS
#
# A Fedora Atomic (bootc/rpm-ostree) image that layers a Mint-style desktop
# session and a few extra daily-driver conveniences on top of Bazzite's
# gaming-tuned Nvidia base. Bazzite already brings SteamOS's gamescope
# Big Picture session and Nobara's driver/codec/gaming patches, so this
# image reuses that work instead of re-deriving it.
#
# Build args let you point this at a different upstream base (e.g. the
# non-Nvidia or handheld Bazzite variants) without editing the file.
ARG BASE_IMAGE="ghcr.io/ublue-os/bazzite-nvidia"
ARG BASE_TAG="stable"

FROM ${BASE_IMAGE}:${BASE_TAG}

ARG IMAGE_NAME="rosaline-os"
ARG IMAGE_VENDOR="Rosaline OS"

COPY system_files /

RUN --mount=type=bind,source=build_files,target=/tmp/build_files,rw \
    /tmp/build_files/build.sh

RUN --mount=type=bind,source=build_files,target=/tmp/build_files,rw \
    /tmp/build_files/cleanup.sh

RUN bootc container lint
