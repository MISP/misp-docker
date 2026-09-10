#!/bin/bash

update_database_tls_config() {
    local key="$1"
    local value="$2"
    local config_file="$3"
    local enable="$4"

    [[ -z "$key" || -z "$config_file" ]] && { echo "key/config_file required"; return 1; }
    [[ ! -f "$config_file" ]] && { echo "Config file not found: $config_file"; return 1; }

    if [[ "$enable" == true && -z "$value" ]]; then
        #echo "Not setting $key as value is empty..."
        return 0
    fi

    if [[ "$enable" == true && "$key" =~ ^(ssl_ca|ssl_cert|ssl_key)$ ]]; then
        if [[ ! -f "$value" ]]; then
            echo "Cannot configure TLS key $key: file $value does not exist..."
            return 1
        fi
    fi

    local tmp
    tmp="$(mktemp)"

    if [[ "$enable" == true ]]; then
        if grep -qE "^[[:space:]]*'${key}'[[:space:]]*=>" "$config_file"; then
            sed -E "s@^([[:space:]]*'${key}'[[:space:]]*=>)[^,]*,@\1 '${value}',@g" \
              "$config_file" > "$tmp"
        else
            sed -E "/public[[:space:]]+\\\$default[[:space:]]*=[[:space:]]*\\[/a\\
        '${key}' => '${value}'," \
              "$config_file" > "$tmp"
        fi
    else
        sed -E "/^[[:space:]]*'${key}'[[:space:]]*=>/d" \
          "$config_file" > "$tmp"
    fi

    if [[ -s "$tmp" ]]; then
        cat "$tmp" > "$config_file"
    fi
    rm -f "$tmp"
}

# safe_sed_i avoids sed -i which creates temp files alongside the target,
# broken on VirtioFS (Docker Desktop for Mac). Uses mktemp + cat pattern.
safe_sed_i() {
    local file="${@: -1}"
    local tmp
    tmp="$(mktemp)"
    if sed "${@:1:$(($#-1))}" "$file" > "$tmp" && [[ -s "$tmp" ]]; then
        cat "$tmp" > "$file"
    fi
    rm -f "$tmp"
}

init_misp_data_files(){
    # Init config (shared with host)
    echo "... initialize configuration files"
    MISP_APP_CONFIG_PATH=/var/www/MISP/app/Config
    # Avoid cp/sed -i which create temp files alongside the target,
    # broken on VirtioFS (Docker Desktop for Mac).
    [ -s $MISP_APP_CONFIG_PATH/bootstrap.php ] || cat $MISP_APP_CONFIG_PATH.dist/bootstrap.default.php > $MISP_APP_CONFIG_PATH/bootstrap.php
    [ -s $MISP_APP_CONFIG_PATH/database.php ] || cat $MISP_APP_CONFIG_PATH.dist/database.default.php > $MISP_APP_CONFIG_PATH/database.php
    [ -s $MISP_APP_CONFIG_PATH/core.php ] || cat $MISP_APP_CONFIG_PATH.dist/core.default.php > $MISP_APP_CONFIG_PATH/core.php
    [ -s $MISP_APP_CONFIG_PATH/config.php.template ] || cat $MISP_APP_CONFIG_PATH.dist/config.default.php > $MISP_APP_CONFIG_PATH/config.php.template
    [ -s $MISP_APP_CONFIG_PATH/config.php ] || echo -e "<?php\n\$config=array();\n?>" > $MISP_APP_CONFIG_PATH/config.php
    [ -s $MISP_APP_CONFIG_PATH/email.php ] || cat $MISP_APP_CONFIG_PATH.dist/email.php > $MISP_APP_CONFIG_PATH/email.php
    [ -s $MISP_APP_CONFIG_PATH/routes.php ] || cat $MISP_APP_CONFIG_PATH.dist/routes.php > $MISP_APP_CONFIG_PATH/routes.php

    if ! grep -q "Detect what auth modules" "$MISP_APP_CONFIG_PATH/bootstrap.php"; then
        echo "... patch bootstrap.php settings"
        chmod +w $MISP_APP_CONFIG_PATH/bootstrap.php
        safe_sed_i -z "s|CakePlugin::loadAll(array(.*CakeResque.*));||g" $MISP_APP_CONFIG_PATH/bootstrap.php
        safe_sed_i "s|CakePlugin::load('AadAuth');||g" $MISP_APP_CONFIG_PATH/bootstrap.php
        safe_sed_i "s|CakePlugin::load('CertAuth');||g" $MISP_APP_CONFIG_PATH/bootstrap.php
        safe_sed_i "s|CakePlugin::load('LdapAuth');||g" $MISP_APP_CONFIG_PATH/bootstrap.php
        safe_sed_i "s|CakePlugin::load('LinOTPAuth');||g" $MISP_APP_CONFIG_PATH/bootstrap.php
        safe_sed_i "s|CakePlugin::load('OidcAuth');||g" $MISP_APP_CONFIG_PATH/bootstrap.php
        safe_sed_i "s|CakePlugin::load('ShibbAuth');||g" $MISP_APP_CONFIG_PATH/bootstrap.php
        cat <<EOT >> $MISP_APP_CONFIG_PATH/bootstrap.php

/**
 * Detect what auth modules need to be loaded based on the loaded config
 */

if (Configure::read('AadAuth')) {
    CakePlugin::load('AadAuth');
}

if (Configure::read('CertAuth')) {
    CakePlugin::load('CertAuth');
}

if (Configure::read('LdapAuth')) {
    CakePlugin::load('LdapAuth');
}

if (Configure::read('LinOTPAuth')) {
    CakePlugin::load('LinOTPAuth');
}

if (Configure::read('OidcAuth')) {
    CakePlugin::load('OidcAuth');
}

if (Configure::read('ShibbAuth')) {
    CakePlugin::load('ShibbAuth');
}

EOT
    else
        echo "... patch bootstrap.php settings not required"
    fi

    echo "... initialize database.php settings"
    # Avoid sed -i which creates temp files alongside the target,
    # broken on VirtioFS (Docker Desktop for Mac).
    chmod +w $MISP_APP_CONFIG_PATH/database.php
    safe_sed_i "s/localhost/$MYSQL_HOST/" $MISP_APP_CONFIG_PATH/database.php
    safe_sed_i "s/db\s*login/$MYSQL_USER/" $MISP_APP_CONFIG_PATH/database.php
    safe_sed_i "s/3306/$MYSQL_PORT/" $MISP_APP_CONFIG_PATH/database.php
    safe_sed_i "s/db\s*password/$MYSQL_PASSWORD/" $MISP_APP_CONFIG_PATH/database.php
    safe_sed_i "s/'database' => 'misp'/'database' => '$MYSQL_DATABASE'/" $MISP_APP_CONFIG_PATH/database.php

    # Enable MySQL TLS immediately, as TLS requiring hosts like AWS RDS may banlist non-TLS connecting hosts
    # Conversely, this is also a good spot to disable it if required

    update_database_tls_config ssl_ca "$MYSQL_TLS_CA" "$MISP_APP_CONFIG_PATH/database.php" "$MYSQL_TLS"
    update_database_tls_config ssl_cert "$MYSQL_TLS_CERT" "$MISP_APP_CONFIG_PATH/database.php" "$MYSQL_TLS"
    update_database_tls_config ssl_key "$MYSQL_TLS_KEY" "$MISP_APP_CONFIG_PATH/database.php" "$MYSQL_TLS"

    echo "... initialize email.php settings"
    chmod +w $MISP_APP_CONFIG_PATH/email.php
    tee $MISP_APP_CONFIG_PATH/email.php > /dev/null <<EOT
<?php
class EmailConfig {
    public \$default = array(
        'transport'     => 'Smtp',
        'from'          => array('misp-dev@admin.test' => 'Misp DEV'),
        'host'          => '$SMTP_FQDN',
        'port'          => $SMTP_PORT,
        'timeout'       => 30,
        'client'        => null,
        'log'           => false,
    );
    public \$smtp = array(
        'transport'     => 'Smtp',
        'from'          => array('misp-dev@admin.test' => 'Misp DEV'),
        'host'          => '$SMTP_FQDN',
        'port'          => $SMTP_PORT,
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
        'host'          => '$SMTP_FQDN',
        'port'          => $SMTP_PORT,
        'timeout'       => 30,
        'client'        => null,
        'log'           => true,
    );
}
EOT

    # Init files (shared with host)
    echo "... initialize app files"
    MISP_APP_FILES_PATH=/var/www/MISP/app/files
    if [ ! -f ${MISP_APP_FILES_PATH}/INIT ]; then
        cp -R ${MISP_APP_FILES_PATH}.dist/* ${MISP_APP_FILES_PATH}
        touch ${MISP_APP_FILES_PATH}/INIT
    fi
}

update_misp_data_files(){
    # If $MISP_APP_FILES_PATH was not changed since the build, skip file updates there
    FILES_VERSION=
    MISP_APP_FILES_PATH=/var/www/MISP/app/files
    CORE_COMMIT=${CORE_COMMIT:-${CORE_TAG}}
    if [ -f ${MISP_APP_FILES_PATH}/VERSION ]; then
        FILES_VERSION=$(cat ${MISP_APP_FILES_PATH}/VERSION)
        echo "... found local files/VERSION:" $FILES_VERSION
        if [ "$FILES_VERSION" = "${CORE_COMMIT:-$(jq -r '"v\(.major).\(.minor).\(.hotfix)"' /var/www/MISP/VERSION.json)}" ]; then
            echo "... local files/ match distribution version, skipping file sync"
            return 0;
        fi
    fi
    for DIR in $(ls /var/www/MISP/app/files.dist); do
        if [ "$DIR" = "certs" ] || [ "$DIR" = "img" ] || [ "$DIR" == "taxonomies" ] || [ "$DIR" == "terms" ] || [ "$DIR" == "misp-objects" ] ; then
            echo "... rsync -azh \"/var/www/MISP/app/files.dist/$DIR\" \"/var/www/MISP/app/files/\""
            rsync -azh "/var/www/MISP/app/files.dist/$DIR" "/var/www/MISP/app/files/"
        else
            echo "... rsync -azh --delete \"/var/www/MISP/app/files.dist/$DIR\" \"/var/www/MISP/app/files/\""
            rsync -azh --delete "/var/www/MISP/app/files.dist/$DIR" "/var/www/MISP/app/files/"
        fi
    done
}

enforce_misp_data_permissions(){
    # If $MISP_APP_FILES_PATH was not changed since the build, skip file updates there
    MISP_APP_FILES_PATH=/var/www/MISP/app/files
    CORE_COMMIT=${CORE_COMMIT:-${CORE_TAG}}
    if [ -f "${MISP_APP_FILES_PATH}/VERSION" ] && [ "$(cat ${MISP_APP_FILES_PATH}/VERSION)" = "${CORE_COMMIT:-$(jq -r '"v\(.major).\(.minor).\(.hotfix)"' /var/www/MISP/VERSION.json)}" ]; then
        echo "... local files/ match distribution version, skipping data permissions in files/"
    else
        echo "find & change ... chown -R www-data:www-data /var/www/MISP/app/tmp" && find /var/www/MISP/app/tmp \( ! -user www-data -or ! -group www-data \) -exec chown www-data:www-data {} +
        # Enforce 0770 on all files and dirs - app/tmp contains a mix of cache, exports and temp files that all need to be writable by www-data
        echo "find & change... chmod -R 0770 /var/www/MISP/app/tmp" && find /var/www/MISP/app/tmp ! -perm 0770 -exec chmod 0770 {} +

        echo "find & change ... chown -R www-data:www-data /var/www/MISP/app/files" && find /var/www/MISP/app/files \( ! -user www-data -or ! -group www-data \) -exec chown www-data:www-data {} +
        # Enforce 0770 on all files and dirs - app/files contains a mix of scripts and user data
        echo "find & change ... chmod -R 0770 /var/www/MISP/app/files" && find /var/www/MISP/app/files ! -perm 0770 -exec chmod 0770 {} +
    fi

    echo "... chown -R www-data:www-data /var/www/MISP/app/Config" && find /var/www/MISP/app/Config \( ! -user www-data -or ! -group www-data \) -exec chown www-data:www-data {} +
    # Files are also executable and read only, because we have some rogue scripts like 'cake' and we can not do a full inventory
    echo "find & change ... chmod -R 0550 files /var/www/MISP/app/Config ..." && find /var/www/MISP/app/Config -type f ! -perm 0550 -exec chmod 0550 {} +
    # Directories are also writable, because there seems to be a requirement to add new files every once in a while
    echo "find & change ... chmod -R 0770 directories /var/www/MISP/app/Config" && find /var/www/MISP/app/Config -type d ! -perm 0770 -exec chmod 0770 {} +
    # We make configuration files read only
    echo "... chmod 600 /var/www/MISP/app/Config/{config,database,email}.php" && chmod 600 /var/www/MISP/app/Config/{bootstrap,config,database,email}.php
}

echo "INIT | Initialize MISP files and configurations ..."
init_misp_data_files

echo "INIT | Update MISP app/files directory ..."
update_misp_data_files

echo "INIT | Enforce MISP permissions ..."
enforce_misp_data_permissions
