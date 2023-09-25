#!/bin/bash

term_proc() {
    echo "Entrypoint NGINX caught SIGTERM signal!"
    echo "Killing process $master_pid"
    kill -TERM "$master_pid" 2>/dev/null
}

trap term_proc SIGTERM

[ -z "$MYSQL_HOST" ] && MYSQL_HOST=db
[ -z "$MYSQL_PORT" ] && MYSQL_PORT=3306
[ -z "$MYSQL_USER" ] && MYSQL_USER=misp
[ -z "$MYSQL_PASSWORD" ] && MYSQL_PASSWORD=example
[ -z "$MYSQL_DATABASE" ] && MYSQL_DATABASE=misp
[ -z "$MYSQLCMD" ] && export MYSQLCMD="mysql -u $MYSQL_USER -p$MYSQL_PASSWORD -P $MYSQL_PORT -h $MYSQL_HOST -r -N $MYSQL_DATABASE"
[ -z "$CRON_USER_ID" ] && export CRON_USER_ID="1"
[ -z "$HOSTNAME" ] && export HOSTNAME="https://localhost"
[ -z "$DISABLE_IPV6" ] && export DISABLE_IPV6=false

init_mysql(){
    # Test when MySQL is ready....
    # wait for Database come ready
    isDBup () {
        echo "SHOW STATUS" | $MYSQLCMD 1>/dev/null
        echo $?
    }

    isDBinitDone () {
        # Table attributes has existed since at least v2.1
        echo "DESCRIBE attributes" | $MYSQLCMD 1>/dev/null
        echo $?
    }

    RETRY=100
    until [ $(isDBup) -eq 0 ] || [ $RETRY -le 0 ] ; do
        echo "... waiting for database to come up"
        sleep 5
        RETRY=$(( RETRY - 1))
    done
    if [ $RETRY -le 0 ]; then
        >&2 echo "... error: Could not connect to Database on $MYSQL_HOST:$MYSQL_PORT"
        exit 1
    fi

    if [ $(isDBinitDone) -eq 0 ]; then
        echo "... database has already been initialized"
    else
        echo "... database has not been initialized, importing MySQL scheme..."
        $MYSQLCMD < /var/www/MISP/INSTALL/MYSQL.sql
    fi
}

init_misp_data_files(){
    # Init config (shared with host)
    echo "... initialize configuration files"
    MISP_APP_CONFIG_PATH=/var/www/MISP/app/Config
    [ -f $MISP_APP_CONFIG_PATH/bootstrap.php ] || cp $MISP_APP_CONFIG_PATH.dist/bootstrap.default.php $MISP_APP_CONFIG_PATH/bootstrap.php
    [ -f $MISP_APP_CONFIG_PATH/database.php ] || cp $MISP_APP_CONFIG_PATH.dist/database.default.php $MISP_APP_CONFIG_PATH/database.php
    [ -f $MISP_APP_CONFIG_PATH/core.php ] || cp $MISP_APP_CONFIG_PATH.dist/core.default.php $MISP_APP_CONFIG_PATH/core.php
    [ -f $MISP_APP_CONFIG_PATH/config.php ] || cp $MISP_APP_CONFIG_PATH.dist/config.default.php $MISP_APP_CONFIG_PATH/config.php
    [ -f $MISP_APP_CONFIG_PATH/email.php ] || cp $MISP_APP_CONFIG_PATH.dist/email.php $MISP_APP_CONFIG_PATH/email.php
    [ -f $MISP_APP_CONFIG_PATH/routes.php ] || cp $MISP_APP_CONFIG_PATH.dist/routes.php $MISP_APP_CONFIG_PATH/routes.php
    
    echo "... initialize database.php settings"
    sed -i "s/localhost/$MYSQL_HOST/" $MISP_APP_CONFIG_PATH/database.php
    sed -i "s/db\s*login/$MYSQL_USER/" $MISP_APP_CONFIG_PATH/database.php
    sed -i "s/db\s*password/$MYSQL_PASSWORD/" $MISP_APP_CONFIG_PATH/database.php
    sed -i "s/'database' => 'misp'/'database' => '$MYSQL_DATABASE'/" $MISP_APP_CONFIG_PATH/database.php

    echo "... initialize email.php settings"
    chmod +w $MISP_APP_CONFIG_PATH/email.php
    tee $MISP_APP_CONFIG_PATH/email.php > /dev/null <<EOT
<?php
class EmailConfig {
    public \$default = array(
        'transport'     => 'Smtp',
        'from'          => array('misp-dev@admin.test' => 'Misp DEV'),
        'host'          => 'mail',
        'port'          => 25,
        'timeout'       => 30,
        'client'        => null,
        'log'           => false,
    );
    public \$smtp = array(
        'transport'     => 'Smtp',
        'from'          => array('misp-dev@admin.test' => 'Misp DEV'),
        'host'          => 'mail',
        'port'          => 25,
        'timeout'       => 30,
        'client'        => null,
        'log'           => false,
    );
    public \$fast = array(
        'from'          => 'misp-dev@admin.test',
        'sender'        => null,
        'to'            => null,
        'cc'            => null,
        'bcc'           => null,
        'replyTo'       => null,
        'readReceipt'   => null,
        'returnPath'    => null,
        'messageId'     => true,
        'subject'       => null,
        'message'       => null,
        'headers'       => null,
        'viewRender'    => null,
        'template'      => false,
        'layout'        => false,
        'viewVars'      => null,
        'attachments'   => null,
        'emailFormat'   => null,
        'transport'     => 'Smtp',
        'host'          => 'mail',
        'port'          => 25,
        'timeout'       => 30,
        'client'        => null,
        'log'           => true,
    );
}
EOT
    chmod -w $MISP_APP_CONFIG_PATH/email.php

    # Init files (shared with host)
    echo "... initialize app files"
    MISP_APP_FILES_PATH=/var/www/MISP/app/files
    if [ ! -f ${MISP_APP_FILES_PATH}/INIT ]; then
        cp -R ${MISP_APP_FILES_PATH}.dist/* ${MISP_APP_FILES_PATH}
        touch ${MISP_APP_FILES_PATH}/INIT
    fi
}

update_misp_data_files(){
    for DIR in $(ls /var/www/MISP/app/files.dist); do
        echo "... rsync -azh --delete \"/var/www/MISP/app/files.dist/$DIR\" \"/var/www/MISP/app/files/\""
        rsync -azh --delete "/var/www/MISP/app/files.dist/$DIR" "/var/www/MISP/app/files/"
    done
}

enforce_misp_data_permissions(){
    echo "... chown -R www-data:www-data /var/www/MISP/app/tmp" && find /var/www/MISP/app/tmp \( ! -user www-data -or ! -group www-data \) -exec chown www-data:www-data {} +
    # Files are also executable and read only, because we have some rogue scripts like 'cake' and we can not do a full inventory
    echo "... chmod -R 0550 files /var/www/MISP/app/tmp" && find /var/www/MISP/app/tmp -not -perm 550 -type f -exec chmod 0550 {} +
    # Directories are also writable, because there seems to be a requirement to add new files every once in a while
    echo "... chmod -R 0770 directories /var/www/MISP/app/tmp" && find /var/www/MISP/app/tmp -not -perm 770 -type d -exec chmod 0770 {} +
    # We make 'files' and 'tmp' (logs) directories and files user and group writable (we removed the SGID bit)
    echo "... chmod -R u+w,g+w /var/www/MISP/app/tmp" && chmod -R u+w,g+w /var/www/MISP/app/tmp
    
    echo "... chown -R www-data:www-data /var/www/MISP/app/files" && find /var/www/MISP/app/files \( ! -user www-data -or ! -group www-data \) -exec chown www-data:www-data {} +
    # Files are also executable and read only, because we have some rogue scripts like 'cake' and we can not do a full inventory
    echo "... chmod -R 0550 files /var/www/MISP/app/files" && find /var/www/MISP/app/files -not -perm 550 -type f -exec chmod 0550 {} +
    # Directories are also writable, because there seems to be a requirement to add new files every once in a while
    echo "... chmod -R 0770 directories /var/www/MISP/app/files" && find /var/www/MISP/app/files -not -perm 770 -type d -exec chmod 0770 {} +
    # We make 'files' and 'tmp' (logs) directories and files user and group writable (we removed the SGID bit)
    echo "... chmod -R u+w,g+w /var/www/MISP/app/files" && chmod -R u+w,g+w /var/www/MISP/app/files
    
    echo "... chown -R www-data:www-data /var/www/MISP/app/Config" && find /var/www/MISP/app/Config \( ! -user www-data -or ! -group www-data \) -exec chown www-data:www-data {} +
    # Files are also executable and read only, because we have some rogue scripts like 'cake' and we can not do a full inventory
    echo "... chmod -R 0550 files /var/www/MISP/app/Config ..." && find /var/www/MISP/app/Config -not -perm 550 -type f -exec chmod 0550 {} +
    # Directories are also writable, because there seems to be a requirement to add new files every once in a while
    echo "... chmod -R 0770 directories /var/www/MISP/app/Config" && find /var/www/MISP/app/Config -not -perm 770 -type d -exec chmod 0770 {} +
    # We make configuration files read only
    echo "... chmod 600 /var/www/MISP/app/Config/{config,database,email}.php" && chmod 600 /var/www/MISP/app/Config/{config,database,email}.php
}

flip_nginx() {
    local live="$1";
    local reload="$2";

    if [[ "$live" = "true" ]]; then
        NGINX_DOC_ROOT=/var/www/MISP/app/webroot
    elif [[ -x /custom/files/var/www/html/index.php ]]; then
        NGINX_DOC_ROOT=/custom/files/var/www/html/
    else
        NGINX_DOC_ROOT=/var/www/html/
    fi

    # must be valid for all roots
    echo "... nginx docroot set to ${NGINX_DOC_ROOT}"
    sed -i "s|root.*var/www.*|root ${NGINX_DOC_ROOT};|" /etc/nginx/sites-available/misp

    if [[ "$reload" = "true" ]]; then
        echo "... nginx reloaded"
        nginx -s reload
    fi
}

init_nginx() {
    # Testing for files also test for links, and generalize better to mounted files
    if [[ ! -f "/etc/nginx/sites-enabled/misp80" ]]; then
        echo "... enabling port 80 redirect"
        if [[ "$DISABLE_IPV6" = "true" ]]; then
            sed -i "/\[::\]/d" /etc/nginx/sites-available/misp80
        fi
        ln -s /etc/nginx/sites-available/misp80 /etc/nginx/sites-enabled/misp80
    else
        echo "... port 80 already configured"
    fi

    # Testing for files also test for links, and generalize better to mounted files
    if [[ ! -f "/etc/nginx/sites-enabled/misp" ]]; then
        echo "... enabling port 443"
        if [[ "$DISABLE_IPV6" = "true" ]]; then
            sed -i "/\[::\]/d" /etc/nginx/sites-available/misp
        fi
        ln -s /etc/nginx/sites-available/misp /etc/nginx/sites-enabled/misp
    else
        echo "... port 443 already configured"
    fi
    
    if [[ ! -f /etc/nginx/certs/cert.pem || ! -f /etc/nginx/certs/key.pem ]]; then
        echo "... generating new self-signed TLS certificate"
        openssl req -x509 -subj '/CN=localhost' -nodes -newkey rsa:4096 -keyout /etc/nginx/certs/key.pem -out /etc/nginx/certs/cert.pem -days 365
    else
        echo "... TLS certificates found"
    fi
    
    if [[ ! -f /etc/nginx/certs/dhparams.pem ]]; then
        echo "... generating new DH parameters"
        openssl dhparam -out /etc/nginx/certs/dhparams.pem 2048
    else
        echo "... DH parameters found"
    fi

    flip_nginx false false
}


# Initialize MySQL
echo "INIT | Initialize MySQL ..." && init_mysql

# Initialize NGINX
echo "INIT | Initialize NGINX ..." && init_nginx
nginx -g 'daemon off;' & master_pid=$!

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

# Wait for it
wait "$master_pid"
