#!/usr/bin/env sh
# -*- coding: utf-8 -*-

set -eu

CONF="${NGINX_INCLUDE_DIR}/real-ip.conf"

# ensure include file exists
mkdir -p "${NGINX_INCLUDE_DIR}" && : > "$CONF"

# early-exit if disabled
if [ "${NGINX_X_FORWARDED_FOR:-false}" != "true" ]; then
    exit 0
fi

IFS=','

# enable forwarding headers
cat >> "$CONF" <<EOF
real_ip_header X-Forwarded-For;
real_ip_recursive on;
EOF

# append each cidr as set_real_ip_from directive
set -- "${NGINX_SET_REAL_IP_FROM:-}"
for CIDR in "$@"; do
    # trim leading/trailing whitespace
    CIDR=$(echo "${CIDR}" | sed 's/^ *//; s/ *$//')

    # skip empty
    [ -n "${CIDR}" ] || continue

    # append as nginx directive
    printf 'set_real_ip_from %s;\n' "${CIDR}" >> "$CONF"
done

# reset separator
unset IFS
