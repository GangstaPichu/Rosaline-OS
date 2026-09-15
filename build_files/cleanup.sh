#!/usr/bin/env bash
#
# Post-install cleanup so layered packages don't bloat the final OCI image.
set -ouex pipefail

dnf5 clean all
# /run/dnf and /var/lib/dnf/repos are dnf5's runtime lock dir and repo
# cache state; both trip `bootc container lint` (nonempty-run-tmp,
# var-tmpfiles) and neither is needed in the shipped image.
rm -rf /var/cache/* /var/log/dnf* /var/tmp/* /run/dnf /var/lib/dnf/repos

# Not a plain `/tmp/*` glob: this script runs with build_files/ still
# bind-mounted at /tmp/build_files (see the Containerfile), and rm -rf
# on an active bind mount deletes through to the *host* source files,
# not just the container's view of them. Skip it explicitly; the mount
# itself is torn down automatically when this RUN step ends.
find /tmp -mindepth 1 -maxdepth 1 ! -name build_files -exec rm -rf {} +
