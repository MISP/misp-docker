#!/bin/bash -e

source /entrypoint_nginx.sh

# Initialize nginx
echo "INIT | Initialize NGINX ..." && init_nginx
echo "INIT | Flip NGINX live ..." && flip_nginx true true

# launch nginx as current shell process in container
exec nginx -g 'daemon off;'

