#!/usr/bin/env sh
# -*- coding: utf-8 -*-

set -eu

REDIRECT_CONF="${NGINX_INCLUDE_DIR}/redirect.conf"
SSL_CONF="${NGINX_INCLUDE_DIR}/ssl.conf"

# ensure include files exists
mkdir -p "${NGINX_INCLUDE_DIR}" && : > "$REDIRECT_CONF" && : > "$SSL_CONF"

if [ ! -f "/etc/nginx/certs/cert.pem" ] || [ ! -f "/etc/nginx/certs/key.pem" ]; then
    exit 0
fi

# normalize redirect url
REDIRECT_URL=${BASE_URL#http://}
REDIRECT_URL=${REDIRECT_URL#https://}
REDIRECT_URL="https://${REDIRECT_URL}"

# build redirect config
cat >> "$REDIRECT_CONF" <<EOF
server {
    server_name misp;
    listen ${NGINX_INTERNAL_HTTP_PORT};

    # remove X-Powered-By and nginx version, which is an information leak
    fastcgi_hide_header X-Powered-By;
    server_tokens off;

    # redirect all traffic to HTTPS
    return 301 ${REDIRECT_URL};
}
EOF

# build ssl block
cat >> "$SSL_CONF" <<EOF
    ssl_certificate /etc/nginx/certs/cert.pem;
    ssl_certificate_key /etc/nginx/certs/key.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ecdh_curve X25519:prime256v1:secp384r1;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305;
    ssl_prefer_server_ciphers off;
    ssl_session_timeout 1d;
    ssl_session_cache shared:MozSSL:10m;  # about 40000 sessions
    ssl_session_tickets off;
EOF
