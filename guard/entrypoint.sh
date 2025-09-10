#!/bin/sh
set -e
MISP_IP=$(getent hosts misp-core | awk '{print $1}')

jq --arg ip "$MISP_IP" \
   '.instances.misp_container.ip = $ip' \
   /srv/misp-guard/src/config.user.json > /srv/misp-guard/src/config.json

exec "$@"