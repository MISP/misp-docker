#!/usr/bin/env sh
# -*- coding: utf-8 -*-

set -eu

CONF="${NGINX_INCLUDE_DIR}/listen.conf"

# ensure include file exists
mkdir -p "${NGINX_INCLUDE_DIR}" && : > "$CONF"

# error out if certs are present but base url is not https based
#
# Skipped when NGINX_TRUST_PROXY_TLS=true: BASE_URL is then expected to be
# https (it's the public URL users/OIDC/etc. see) while this container has
# no local certificate on purpose, because TLS is already terminated by an
# upstream reverse proxy/ingress that forwards plain HTTP here. Replaces the
# old (removed upstream) DISABLE_SSL_REDIRECT escape hatch for that case.
if [ "${NGINX_TRUST_PROXY_TLS:-false}" != "true" ]; then
    if [ -f "/etc/nginx/certs/cert.pem" ] && [ -f "/etc/nginx/certs/key.pem" ]; then
        case "$BASE_URL" in
        http://*)
            echo "BASE_URL starts with http://, but SSL certificate is present. Please update your env variables!"
            exit 1
            ;;
        esac
    else
        case "$BASE_URL" in
        https://*)
            echo "BASE_URL starts with https://, but SSL certificate is NOT present. Please update your env variables!"
            exit 1
            ;;
        esac
    fi
fi

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
