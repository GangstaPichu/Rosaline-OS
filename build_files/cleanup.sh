#!/usr/bin/env bash
#
# Post-install cleanup so layered packages don't bloat the final OCI image.
set -ouex pipefail

dnf5 clean all
rm -rf /var/cache/* /var/log/dnf* /tmp/* /var/tmp/*
