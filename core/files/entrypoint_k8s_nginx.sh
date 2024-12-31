#!/bin/bash

source /entrypoint_nginx.sh

# Initialize nginx
echo "INIT | Initialize NGINX ..." && init_nginx

# launch nginx as current shell process in container
exec nginx -g 'daemon off;'

