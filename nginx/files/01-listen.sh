#!/usr/bin/env sh
# -*- coding: utf-8 -*-

set -eu

CONF="${NGINX_INCLUDE_DIR}/listen.conf"

# ensure include file exists
mkdir -p "${NGINX_INCLUDE_DIR}" && : > "$CONF"

if [ -f "/etc/nginx/certs/cert.pem" ] && [ -f "/etc/nginx/certs/key.pem" ]; then
    # ipv4-ssl
    printf 'listen %s ssl;\n' "${NGINX_INTERNAL_HTTPS_PORT}" >> "$CONF"

    # ipv6-ssl
    if [ "${DISABLE_IPV6}" != "true" ]; then
        printf 'listen [::]:%s ssl;\n' "${NGINX_INTERNAL_HTTPS_PORT}" >> "$CONF"
    fi
else
    # ipv4
    printf 'listen %s;\n' "${NGINX_INTERNAL_HTTP_PORT}" >> "$CONF"

    # ipv6
    if [ "${DISABLE_IPV6}" != "true" ]; then
        printf 'listen [::]:%s;\n' "${NGINX_INTERNAL_HTTP_PORT}" >> "$CONF"
    fi
fi
