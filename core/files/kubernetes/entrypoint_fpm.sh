#!/bin/bash -e

echo "INIT | Loading environment and functions"

source /entrypoint.sh
source /entrypoint_fpm.sh

# Configure supervisord for kubernetes
echo "INIT | Configuring supervisord for kubernetes"
mv /etc/supervisor/conf.d/10-supervisor.conf{.kubernetes,}
mv /etc/supervisor/conf.d/50-workers.conf{.kubernetes,}

# Starting supervisord
echo "INIT | Starting supervisord"
/usr/local/bin/supervisord -c /etc/supervisor/supervisord.conf &

# Initialize MySQL
echo "INIT | Initialize MySQL ..."
init_mysql

# Initialize MISP
echo "INIT | Initialize MISP installation ..."
/init_misp.sh

# Mirror logs to stdout
echo "INIT | Mirror file logs to stdout ..."
redirect_logs

# Run configure MISP script
echo "INIT | Configure MISP installation ..."
/configure_misp.sh

if [[ -x /custom/files/customize_misp.sh ]]; then
    echo "INIT | Customize MISP installation ..."
    /custom/files/customize_misp.sh
fi

# Configure PHP
echo "Configure PHP | Change PHP values ..."
change_php_vars

echo "MISP | Starting PHP FPM"
exec /usr/bin/tini -- /usr/local/sbin/php-fpm -R -F
