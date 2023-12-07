#!/bin/bash

# export env variables again so they are not mandatory in docker-compose.yml in a backward compatible manner
export NUM_WORKERS_DEFAULT=${NUM_WORKERS_DEFAULT:-${WORKERS:-5}}
export NUM_WORKERS_PRIO=${NUM_WORKERS_PRIO:-${WORKERS:-5}}
export NUM_WORKERS_EMAIL=${NUM_WORKERS_EMAIL:-${WORKERS:-5}}
export NUM_WORKERS_UPDATE=${NUM_WORKERS_UPDATE:-${WORKERS:-1}}
export NUM_WORKERS_CACHE=${NUM_WORKERS_CACHE:-${WORKERS:-5}}

# start supervisord using the main configuration file so we have a socket interface
/usr/bin/supervisord -c /etc/supervisor/supervisord.conf
