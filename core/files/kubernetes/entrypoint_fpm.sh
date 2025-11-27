#!/bin/bash -e
echo "INIT | Loading environment and functions"
source /entrypoint.sh
export PHP_LISTEN_FPM=true
source /entrypoint_nginx.sh
source /entrypoint_fpm.sh

echo "INIT | Configuring supervisord for kubernetes"
mv /etc/supervisor/conf.d/10-supervisor.conf{.kubernetes,}
mv /etc/supervisor/conf.d/50-workers.conf{.kubernetes,}

echo "INIT | Starting supervisord"
/usr/local/bin/supervisord -c /etc/supervisor/supervisord.conf &

# Initialize MySQL
echo "INIT | Initialize MySQL ..." && init_mysql

# Initialize MISP
echo "INIT | Initialize MISP files and configurations ..." && init_misp_data_files
echo "INIT | Update MISP app/files directory ..." && update_misp_data_files
echo "INIT | Mirror file logs to stdout ..." && redirect_logs
echo "INIT | Enforce MISP permissions ..." && enforce_misp_data_permissions

# Run configure MISP script
echo "INIT | Configure MISP installation ..."
/configure_misp.sh

if [[ -x /custom/files/customize_misp.sh ]]; then
    echo "INIT | Customize MISP installation ..."
    /custom/files/customize_misp.sh
fi

echo "Configure PHP | Change PHP values ..." && change_php_vars

echo "Configure PHP | Starting PHP FPM"

exec /usr/bin/tini -- /usr/sbin/php-fpm8.4 -R -F
