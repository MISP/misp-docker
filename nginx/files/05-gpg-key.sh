#!/usr/bin/env sh
# -*- coding: utf-8 -*-

set -eu

GPG_SRC_ASC="/var/www/MISP/.gnupg/gpg.asc"
GPG_DEST_ASC="/var/www/MISP/cache/gpg.asc"

# ensure target directory exists
mkdir -p "$(dirname "${GPG_DEST_ASC}")"

# skip if key is missing
if [ ! -f "${GPG_SRC_ASC}" ]; then
    exit 0
fi

# place gpg key in misp cache directory
cp "${GPG_SRC_ASC}" "${GPG_DEST_ASC}"

# ensure permissions for nginx user
chown nginx:nginx "${GPG_DEST_ASC}"
