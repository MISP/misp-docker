#!/bin/bash -e
echo "INIT | Loading environment and functions"
source /entrypoint.sh
source /entrypoint_nginx.sh

# Initialize nginx
echo "INIT | Initialize NGINX ..." && init_nginx

echo "... setting 'fastcgi_pass' to misp-php:9002"
sed -i "s@fastcgi_pass .*;@fastcgi_pass misp-php:9002;@" /etc/nginx/includes/misp

echo "INIT | Flip NGINX live ..." && flip_nginx true false

# launch nginx as current shell process in container
exec /usr/bin/tini -- nginx -g 'daemon off;'