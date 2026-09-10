#!/bin/bash

term_proc() {
    echo "Entrypoint FPM caught SIGTERM signal!"
    echo "Killing process $master_pid"
    kill -TERM "$master_pid" 2>/dev/null
}

trap term_proc SIGTERM

init_mysql() {
    # Test when MySQL is ready....
    # wait for Database come ready
    isDBup () {
        echo "SHOW STATUS" | $MYSQL_CMD 1>/dev/null
        echo $?
    }

    isDBinitDone () {
        # Table attributes has existed since at least v2.1
        echo "DESCRIBE attributes" | $MYSQL_CMD 1>/dev/null
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
        export DB_ALREADY_INITIALISED=true
    else
        echo "... database has not been initialized, importing MySQL scheme..."
        $MYSQL_CMD < /var/www/MISP/INSTALL/MYSQL.sql
    fi
}

redirect_logs() {
    tail -F /var/www/MISP/app/tmp/logs/error.log > /dev/stdout 2>/dev/null &
}

change_php_vars() {
    ESCAPED=$(printf '%s\n' "$REDIS_PASSWORD" | sed -e 's/[\/&]/\\&/g')
    for FILE in /etc/php/*/fpm/php.ini
    do
        [[ -e $FILE ]] || break
        echo "Configure PHP | Setting 'memory_limit = ${PHP_MEMORY_LIMIT}'"
        sed -i "s/memory_limit = .*/memory_limit = ${PHP_MEMORY_LIMIT}/" "$FILE"
        echo "Configure PHP | Setting 'max_execution_time = ${PHP_MAX_EXECUTION_TIME}'"
        sed -i "s/max_execution_time = .*/max_execution_time = ${PHP_MAX_EXECUTION_TIME}/" "$FILE"
        echo "Configure PHP | Setting 'upload_max_filesize = ${PHP_UPLOAD_MAX_FILESIZE}'"
        sed -i "s/upload_max_filesize = .*/upload_max_filesize = ${PHP_UPLOAD_MAX_FILESIZE}/" "$FILE"
        echo "Configure PHP | Setting 'max_file_uploads = ${PHP_MAX_FILE_UPLOADS}'"
        sed -i "s/max_file_uploads = .*/max_file_uploads = ${PHP_MAX_FILE_UPLOADS}/" "$FILE"
        echo "Configure PHP | Setting 'post_max_size = ${PHP_POST_MAX_SIZE}'"
        sed -i "s/post_max_size = .*/post_max_size = ${PHP_POST_MAX_SIZE}/" "$FILE"
        echo "Configure PHP | Setting 'max_input_time = ${PHP_MAX_INPUT_TIME}'"
        sed -i "s/max_input_time = .*/max_input_time = ${PHP_MAX_INPUT_TIME}/" "$FILE"
        sed -i "s/session.save_handler = .*/session.save_handler = redis/" "$FILE"
        if [[ "$ENABLE_REDIS_EMPTY_PASSWORD" = "true" ]]; then
            echo "Configure PHP | Setting 'session.save_path = '$(echo $REDIS_HOST | grep -E '^\w+://' || echo tcp://$REDIS_HOST):$REDIS_PORT' (passwordless)"
            sed -i "s|.*session.save_path = .*|session.save_path = '$(echo $REDIS_HOST | grep -E '^\w+://' || echo tcp://$REDIS_HOST):$REDIS_PORT'|" "$FILE"
        elif [[ -n "$REDIS_PASSWORD" ]]; then
            if [ "$DISABLE_PRINTING_PLAINTEXT_CREDENTIALS" == "true" ]; then
                echo "Configure PHP | Setting 'session.save_path = '$(echo $REDIS_HOST | grep -E '^\w+://' || echo tcp://$REDIS_HOST):$REDIS_PORT?auth=<hidden>'"
            else
                echo "Configure PHP | Setting 'session.save_path = '$(echo $REDIS_HOST | grep -E '^\w+://' || echo tcp://$REDIS_HOST):$REDIS_PORT?auth=${ESCAPED}'"
            fi
            sed -i "s|.*session.save_path = .*|session.save_path = '$(echo $REDIS_HOST | grep -E '^\w+://' || echo tcp://$REDIS_HOST):$REDIS_PORT?auth=${ESCAPED}'|" "$FILE"
        else
            echo "ERROR: REDIS_PASSWORD is not set but ENABLE_REDIS_EMPTY_PASSWORD is false. Please set REDIS_PASSWORD or enable ENABLE_REDIS_EMPTY_PASSWORD=true for passwordless Redis."
            exit 1
        fi
        sed -i "s/session.sid_length = .*/session.sid_length = 64/" "$FILE"
        sed -i "s/session.use_strict_mode = .*/session.use_strict_mode = 1/" "$FILE"
        echo "Configure PHP | Setting 'date.timezone = ${TZ}'"
        sed -i "s|^;date.timezone =.*|date.timezone = ${TZ}|" "$FILE"
    done

    for FILE in /etc/php/*/cli/php.ini
    do
        [[ -e $FILE ]] || break
        echo "Configure PHP (CLI) | Setting 'date.timezone = ${TZ}'"
        sed -i "s|^;date.timezone =.*|date.timezone = ${TZ}|" "$FILE"
    done

    for FILE in /etc/php/*/fpm/pool.d/www.conf
    do
        [[ -e $FILE ]] || break
        echo "Configure PHP | Setting 'pm.max_children = ${PHP_FCGI_CHILDREN}'"
        sed -i -E "s/;?pm.max_children = .*/pm.max_children = ${PHP_FCGI_CHILDREN}/" "$FILE"
        echo "Configure PHP | Setting 'pm.start_servers = ${PHP_FCGI_START_SERVERS}'"
        sed -i -E "s/;?pm.start_servers = .*/pm.start_servers = ${PHP_FCGI_START_SERVERS}/" "$FILE"
        echo "Configure PHP | Setting 'pm.(min|max)_spare_servers = ${PHP_FCGI_START_SERVERS}'"
        sed -i -E "s/;?pm.min_spare_servers = .*/pm.min_spare_servers = ${PHP_FCGI_SPARE_SERVERS}/" "$FILE"
        if [[ "$PHP_FCGI_START_SERVERS" -gt "$PHP_FCGI_SPARE_SERVERS" ]]; then
            sed -i -E "s/;?pm.max_spare_servers = .*/pm.max_spare_servers = ${PHP_FCGI_START_SERVERS}/" "$FILE"
        else
            sed -i -E "s/;?pm.max_spare_servers = .*/pm.max_spare_servers = ${PHP_FCGI_SPARE_SERVERS}/" "$FILE"
        fi
        echo "Configure PHP | Setting 'pm.max_requests = ${PHP_FCGI_MAX_REQUESTS}'"
        sed -i -E "s/;?pm.max_requests = .*/pm.max_requests = ${PHP_FCGI_MAX_REQUESTS}/" "$FILE"
        if [[ "$FASTCGI_LISTEN_STATUS" != "" ]]; then
            echo "Configure PHP | Setting 'pm.status_path = /fpm-status'"
            sed -i -E "s/;?pm.status_path = .*/pm.status_path = \/fpm-status/" "$FILE"
            if [[ -n "$PHP_LISTEN_FPM" ]]; then
                echo "Configure PHP | Setting 'pm.status_listen' to [::]:9003"
                sed -i -E "s/;?pm.status_listen = .*/pm.status_listen = [::]:9003/" "$FILE"
            else
                echo "Configure PHP | Setting 'pm.status_listen = /run/php/php-fpm-status.sock'"
                sed -i -E "s/;?pm.status_listen = .*/pm.status_listen = \/run\/php\/php-fpm-status.sock/" "$FILE"
            fi
        else
            echo "Configure PHP | Disabling 'pm.status_path'"
            sed -i -E "s/^pm.status_path = /;pm.status_path = /" "$FILE"
            echo "Configure PHP | Disabling 'pm.status_listen'"
            sed -i -E "s/^pm.status_listen =/;pm.status_listen =/" "$FILE"
        fi
        if [[ -n "$PHP_LISTEN_FPM" ]]; then
            if [[ "$DISABLE_IPV6" = "true" ]]; then
                echo "Configure PHP | Setting 'listen' to 0.0.0.0:9002"
                sed -i "/^listen =/s@=.*@= 0.0.0.0:9002@" "$FILE"
            else
                echo "Configure PHP | Setting 'listen' to [::]:9002"
                sed -i "/^listen =/s@=.*@= [::]:9002@" "$FILE"
            fi
        fi

    done
}

# Hinders further execution when sourced from other scripts
if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
    return
fi

echo "INIT | Loading environment and functions"

# Initialize MySQL
echo "INIT | Initialize MySQL ..."
init_mysql

echo "INIT | Change PHP values ..."
change_php_vars

# Initialize MISP
echo "INIT | Initialize MISP installation ..."
/init_misp.sh

# Run configure MISP script
echo "INIT | Configure MISP installation ..."
/configure_misp.sh

# Run customization scripts
if [[ -x /custom/files/customize_misp.sh ]]; then
    echo "INIT | Customize MISP installation ..."
    /custom/files/customize_misp.sh
fi

echo "MISP | Starting PHP FPM"
/usr/local/sbin/php-fpm -R -F & master_pid=$!

# Wait for it
wait "$master_pid"
