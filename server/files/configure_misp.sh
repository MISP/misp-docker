#!/bin/bash

source /rest_client.sh

[ -z "$ADMIN_EMAIL" ] && ADMIN_EMAIL="admin@admin.test"
[ -z "$GPG_PASSPHRASE" ] && GPG_PASSPHRASE="passphrase"
[ -z "$REDIS_FQDN" ] && REDIS_FQDN=redis
[ -z "$MISP_MODULES_FQDN" ] && MISP_MODULES_FQDN="http://misp-modules"

init_configuration(){
    # Note that we are doing this after enforcing permissions, so we need to use the www-data user for this
    echo "... configuring default settings"
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting "MISP.redis_host" "$REDIS_FQDN"
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting "MISP.baseurl" "$HOSTNAME"
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting "MISP.python_bin" $(which python3)
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting "Plugin.ZeroMQ_redis_host" "$REDIS_FQDN"
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting "Plugin.ZeroMQ_enable" true
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting "Plugin.Enrichment_services_enable" true
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting "Plugin.Enrichment_services_url" "$MISP_MODULES_FQDN"
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting "Plugin.Import_services_enable" true
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting "Plugin.Import_services_url" "$MISP_MODULES_FQDN"
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting "Plugin.Export_services_enable" true
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting "Plugin.Export_services_url" "$MISP_MODULES_FQDN"
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting "Plugin.Cortex_services_enable" false
}

init_workers(){
    # Note that we are doing this after enforcing permissions, so we need to use the www-data user for this
    echo "... configuring background workers"
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting "SimpleBackgroundJobs.enabled" true
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting "SimpleBackgroundJobs.supervisor_host" "127.0.0.1"
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting "SimpleBackgroundJobs.supervisor_port" 9001
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting "SimpleBackgroundJobs.supervisor_password" "supervisor"
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting "SimpleBackgroundJobs.supervisor_user" "supervisor"
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting "SimpleBackgroundJobs.redis_host" "$REDIS_FQDN"

    echo "... starting background workers"
    supervisorctl start misp-workers:*
}

configure_gnupg() {
    GPG_DIR=/var/www/MISP/.gnupg
    GPG_ASC=/var/www/MISP/app/webroot/gpg.asc
    GPG_TMP=/tmp/gpg.tmp

    if [ ! -f "${GPG_DIR}/trustdb.gpg" ]; then
        echo "... generating new GPG key in ${GPG_DIR}"
        cat >${GPG_TMP} <<GPGEOF
%echo Generating a basic OpenPGP key
Key-Type: RSA
Key-Length: 3072
Name-Real: MISP Admin
Name-Email: $ADMIN_EMAIL
Expire-Date: 0
Passphrase: $GPG_PASSPHRASE
%commit
%echo Done
GPGEOF
        mkdir ${GPG_DIR}
        gpg --homedir ${GPG_DIR} --gen-key --batch ${GPG_TMP}
        rm -f ${GPG_TMP}
    else
        echo "... found pre-generated GPG key in ${GPG_DIR}"
    fi

    # Fix permissions
    chown -R www-data:www-data ${GPG_DIR}
    find ${GPG_DIR} -type f -exec chmod 600 {} \;
    find ${GPG_DIR} -type d -exec chmod 700 {} \;

    if [ ! -f ${GPG_ASC} ]; then
        echo "... exporting GPG key"
        sudo -u www-data gpg --homedir ${GPG_DIR} --export --armor ${ADMIN_EMAIL} > ${GPG_ASC}
    else
        echo "... found exported key ${GPG_ASC}"
    fi

    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting "GnuPG.email" "${ADMIN_EMAIL}"
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting "GnuPG.homedir" "${GPG_DIR}"
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting "GnuPG.password" "${GPG_PASSPHRASE}"
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting "GnuPG.obscure_subject" false
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting "GnuPG.binary" "$(which gpg)"
}

apply_updates() {
    # Disable weird default
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting "Plugin.ZeroMQ_enable" false
    # Run updates
    sudo -u www-data /var/www/MISP/app/Console/cake Admin runUpdates
}

init_user() {
    # Create the main user if it is not there already
    sudo -u www-data /var/www/MISP/app/Console/cake userInit -q
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting "MISP.email" ${ADMIN_EMAIL}
    echo 'UPDATE misp.users SET change_pw = 0 WHERE id = 1;' | ${MYSQLCMD}
    echo "UPDATE misp.users SET email = \"${ADMIN_EMAIL}\" WHERE id = 1;" | ${MYSQLCMD}
    if [ ! -z "$ADMIN_ORG" ]; then
        echo "UPDATE misp.organisations SET name = \"${ADMIN_ORG}\" where id = 1;" | ${MYSQLCMD}
    fi
    if [ ! -z "$ADMIN_KEY" ]; then
        echo "... setting admin key to '${ADMIN_KEY}'"
        CHANGE_CMD=(sudo -u www-data /var/www/MISP/app/Console/cake User change_authkey 1 "${ADMIN_KEY}")
    else
        echo "... regenerating admin key"
        CHANGE_CMD=(sudo -u www-data /var/www/MISP/app/Console/cake User change_authkey 1)
    fi
    ADMIN_KEY=`${CHANGE_CMD[@]} | awk 'END {print $NF; exit}'`
    echo "... admin user key set to '${ADMIN_KEY}'"
}

apply_critical_fixes() {
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting "MISP.external_baseurl" "${HOSTNAME}"
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting "MISP.host_org_id" 1
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting "Plugin.Action_services_enable" false
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting "Plugin.Enrichment_hover_enable" false
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting "Plugin.Enrichment_hover_popover_only" false
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting "Security.csp_enforce" true
    sudo -u www-data php /var/www/MISP/tests/modify_config.php modify "{
        \"Security\": {
            \"rest_client_baseurl\": \"${HOSTNAME}\"
        }
    }" > /dev/null
    sudo -u www-data php /var/www/MISP/tests/modify_config.php modify "{
        \"Security\": {
            \"auth\": \"\"
        }
    }" > /dev/null
}

apply_optional_fixes() {
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting --force "MISP.welcome_text_top" ""
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting --force "MISP.welcome_text_bottom" ""
    
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting "MISP.contact" "${ADMIN_EMAIL}"
    # This is not necessary because we update the DB directly
    # sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting "MISP.org" "${ADMIN_ORG}"
    
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting "MISP.log_client_ip" true
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting "MISP.log_user_ips" true
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting "MISP.log_user_ips_authkeys" true

    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting "Plugin.Enrichment_timeout" 30
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting "Plugin.Enrichment_hover_timeout" 5
}

update_components() {
    sudo -u www-data /var/www/MISP/app/Console/cake Admin updateGalaxies
    sudo -u www-data /var/www/MISP/app/Console/cake Admin updateTaxonomies
    sudo -u www-data /var/www/MISP/app/Console/cake Admin updateWarningLists
    sudo -u www-data /var/www/MISP/app/Console/cake Admin updateNoticeLists
    sudo -u www-data /var/www/MISP/app/Console/cake Admin updateObjectTemplates "$CRON_USER_ID"
}

create_sync_servers() {
    SPLITTED_SYNCSERVERS=$(echo $SYNCSERVERS | tr ',' '\n')
    for ID in $SPLITTED_SYNCSERVERS; do
        NAME="SYNCSERVERS_${ID}_NAME"
        UUID="SYNCSERVERS_${ID}_UUID"
        DATA="SYNCSERVERS_${ID}_DATA"
        KEY="SYNCSERVERS_${ID}_KEY"
        echo "... searching sync server ${!NAME}..."
        if ! get_server ${HOSTNAME} ${ADMIN_KEY} ${!NAME}; then
            echo "... adding new sync server ${!NAME}..."
            add_organization ${HOSTNAME} ${ADMIN_KEY} ${!NAME} false ${!UUID}
            ORG_ID=$(get_organization ${HOSTNAME} ${ADMIN_KEY} ${!UUID})
            DATA=$(echo "${!DATA}" | jq --arg org_id ${ORG_ID} --arg name ${!NAME} --arg key ${!KEY} '. + {remote_org_id: $org_id, name: $name, authkey: $key}')
            add_server ${HOSTNAME} ${ADMIN_KEY} "$DATA"
        else
            echo "... found existing sync server ${!NAME}..."
        fi
    done   
}


echo "MISP | Initialize configuration ..." && init_configuration

echo "MISP | Initialize workers ..." && init_workers

echo "MISP | Configure GPG key ..." && configure_gnupg

echo "MISP | Apply updates ..." && apply_updates

echo "MISP | Init default user and organization ..." && init_user

echo "MISP | Resolve critical issues ..." && apply_critical_fixes

echo "MISP | Resolve non-critical issues ..." && apply_optional_fixes

echo "MISP | Create sync servers ..." && create_sync_servers

echo "MISP | Update components ..." && update_components

echo "MISP | Mark instance live"
sudo -u www-data /var/www/MISP/app/Console/cake Admin live 1
