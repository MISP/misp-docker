#!/usr/bin/env sh
# -*- coding: utf-8 -*-

set -eu

CONF="${NGINX_INCLUDE_DIR}/conditional-headers.conf"

# ensure include file exists
mkdir -p "${NGINX_INCLUDE_DIR}" && : > "$CONF"

# configure content security policy header
if [ -n "${NGINX_CONTENT_SECURITY_POLICY:-}" ]; then
    printf 'add_header Content-Security-Policy "%s";\n' "${NGINX_CONTENT_SECURITY_POLICY}" >> "$CONF"
fi

# configure strict transport security header
if [ -n "${NGINX_HSTS_MAX_AGE:-}" ]; then
    printf 'add_header Strict-Transport-Security "max-age=%s; includeSubdomains";\n' "${NGINX_HSTS_MAX_AGE}" >> "$CONF"
fi
