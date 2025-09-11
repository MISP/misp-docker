#!/bin/sh

# Entry point for misp-guard.
# This ensures MISP-core's IP is set at runtime when misp-guard starts.
# config.json must reflect this structure to ensure the source container is targeted
# {
#   "instances": {
#     "misp_container": {
#       "ip": "placeholder"
#     }
#   }
# }


set -e

# resolve misp-core from docker dns
MISP_IP=$(getent hosts misp-core | awk '{print $1}')

# replace runtime ip into config.json
jq --arg ip "$MISP_IP" \
   '.instances.misp_container.ip = $ip' \
   /srv/misp-guard/src/config.user.json > /srv/misp-guard/src/config.json

exec "$@"