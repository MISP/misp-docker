#!/bin/bash
set -euo pipefail

# Fixes ownership of misp-core's bind-mounted host directories before
# misp-core itself starts. misp-core runs as a fixed non-root user (33:0)
# from process 1 and can no longer chown these on its own on first start -
# see entrypoint.sh's nss_wrapper comment for the same underlying
# constraint. This runs as root, once, via docker-compose.yml's
# misp-core-init service (entrypoint override + user: "0:0"), which
# misp-core depends on via condition: service_completed_successfully.
#
# Only misp-core's own bind mounts are listed here. misp-nginx's ./ssl
# mount is read-only (nginx never writes to it) and needs no ownership
# fix - see the "Certificates" section of README.md for its own
# (read-permission, not ownership) constraint instead.
TARGETS=(
    /var/www/MISP/app/Config
    /var/www/MISP/app/tmp/logs
    /var/www/MISP/app/files
    /var/www/MISP/.gnupg
)

for path in "${TARGETS[@]}"; do
    if [ ! -d "$path" ]; then
        echo "init: $path is not mounted, skipping"
        continue
    fi

    owner="$(stat -c '%u:%g' "$path")"
    if [ "$owner" = "33:0" ]; then
        echo "init: $path already owned by 33:0, skipping"
        continue
    fi

    echo "init: fixing ownership of $path (was $owner)"
    chown -R 33:0 "$path"
    chmod -R g+rwX "$path"
done
