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
if [ -z "$MISP_IP" ]; then
  MISP_IP=$(getent hosts misp-core | awk '{print $1}')
fi

# replace runtime ip into config.json
jq --arg ip "$MISP_IP" \
   '.instances.misp_container.ip = $ip' \
   /config.json > /srv/misp-guard/src/config.json

exec mitmdump -s mispguard.py -p ${GUARD_PORT:-8888} ${GUARD_ARGS:+$GUARD_ARGS} --set config=config.json
