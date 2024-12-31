#!/bin/bash

source /entrypoint_nginx.sh
source /entrypoint_fpm.sh

# Initialize MySQL
echo "INIT | Initialize MySQL ..." && init_mysql

# Initialize MISP
echo "INIT | Initialize MISP files and configurations ..." && init_misp_data_files
echo "INIT | Update MISP app/files directory ..." && update_misp_data_files
echo "INIT | Enforce MISP permissions ..." && enforce_misp_data_permissions
echo "INIT | Flip NGINX live ..." && flip_nginx true true

# Run configure MISP script
echo "INIT | Configure MISP installation ..."
/configure_misp.sh

if [[ -x /custom/files/customize_misp.sh ]]; then
    echo "INIT | Customize MISP installation ..."
    /custom/files/customize_misp.sh
fi

echo "Configure PHP | Change PHP values ..." && change_php_vars

echo "Configure PHP | Starting PHP FPM"
exec /usr/sbin/php-fpm8.2 -R -F
