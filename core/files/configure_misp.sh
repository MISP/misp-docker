#!/bin/bash

source /rest_client.sh
source /utilities.sh

[ -z "$ADMIN_EMAIL" ] && ADMIN_EMAIL="admin@admin.test"
[ -z "$GPG_PASSPHRASE" ] && GPG_PASSPHRASE="passphrase"
[ -z "$REDIS_FQDN" ] && REDIS_FQDN="redis"
[ -z "$MISP_MODULES_FQDN" ] && MISP_MODULES_FQDN="http://misp-modules"

# Switches to selectively disable configuration logic
[ -z "$AUTOCONF_GPG" ] && AUTOCONF_GPG="true"
[ -z "$AUTOCONF_ADMIN_KEY" ] && AUTOCONF_ADMIN_KEY="true"
[ -z "$OIDC_ENABLE" ] && OIDC_ENABLE="false"
[ -z "$LDAP_ENABLE" ] && LDAP_ENABLE="false"

init_configuration(){
    # Note that we are doing this after enforcing permissions, so we need to use the www-data user for this
    echo "... configuring default settings"
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting -q "MISP.baseurl" "$BASE_URL"
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting -q "MISP.email" "${MISP_EMAIL-$ADMIN_EMAIL}"
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting -q "MISP.contact" "${MISP_CONTACT-$ADMIN_EMAIL}"
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting -q "MISP.redis_host" "$REDIS_FQDN"
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting -q "MISP.python_bin" $(which python3)
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting -q -f "MISP.ca_path" "/etc/ssl/certs/ca-certificates.crt"
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting -q "Plugin.ZeroMQ_redis_host" "$REDIS_FQDN"
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting -q "Plugin.ZeroMQ_enable" true
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting -q "Plugin.Enrichment_services_enable" true
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting -q "Plugin.Enrichment_services_url" "$MISP_MODULES_FQDN"
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting -q "Plugin.Import_services_enable" true
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting -q "Plugin.Import_services_url" "$MISP_MODULES_FQDN"
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting -q "Plugin.Export_services_enable" true
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting -q "Plugin.Export_services_url" "$MISP_MODULES_FQDN"
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting -q "Plugin.Cortex_services_enable" false
}

init_workers(){
    # Note that we are doing this after enforcing permissions, so we need to use the www-data user for this
    echo "... configuring background workers"
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting -q "SimpleBackgroundJobs.enabled" true
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting -q "SimpleBackgroundJobs.supervisor_host" "127.0.0.1"
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting -q "SimpleBackgroundJobs.supervisor_port" 9001
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting -q "SimpleBackgroundJobs.supervisor_password" "supervisor"
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting -q "SimpleBackgroundJobs.supervisor_user" "supervisor"
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting -q "SimpleBackgroundJobs.redis_host" "$REDIS_FQDN"

    echo "... starting background workers"
    supervisorctl start misp-workers:*
}

configure_gnupg() {
    if [ "$AUTOCONF_GPG" != "true" ]; then
        echo "... GPG auto configuration disabled"
        return
    fi

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
Name-Email: ${MISP_EMAIL-$ADMIN_EMAIL}
Expire-Date: 0
Passphrase: $GPG_PASSPHRASE
%commit
%echo Done
GPGEOF
        mkdir -p ${GPG_DIR}
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
        sudo -u www-data gpg --homedir ${GPG_DIR} --export --armor ${MISP_EMAIL-$ADMIN_EMAIL} > ${GPG_ASC}
    else
        echo "... found exported key ${GPG_ASC}"
    fi

    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting -q "GnuPG.email" "${MISP_EMAIL-$ADMIN_EMAIL}"
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting -q "GnuPG.homedir" "${GPG_DIR}"
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting -q "GnuPG.password" "${GPG_PASSPHRASE}"
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting -q "GnuPG.binary" "$(which gpg)"
}

set_up_oidc() {
    if [[ "$OIDC_ENABLE" != "true" ]]; then
        echo "... OIDC authentication disabled"
        return
    fi

    # Check required variables
    check_env_vars OIDC_PROVIDER_URL OIDC_CLIENT_ID OIDC_CLIENT_SECRET OIDC_ROLES_PROPERTY OIDC_ROLES_MAPPING OIDC_DEFAULT_ORG

    sudo -u www-data php /var/www/MISP/tests/modify_config.php modify "{
        \"Security\": {
            \"auth\": [\"OidcAuth.Oidc\"]
        }
    }" > /dev/null

    sudo -u www-data php /var/www/MISP/tests/modify_config.php modify "{
        \"OidcAuth\": {
            \"provider_url\": \"${OIDC_PROVIDER_URL}\",
            \"client_id\": \"${OIDC_CLIENT_ID}\",
            \"client_secret\": \"${OIDC_CLIENT_SECRET}\",
            \"roles_property\": \"${OIDC_ROLES_PROPERTY}\",
            \"role_mapper\": ${OIDC_ROLES_MAPPING},
            \"default_org\": \"${OIDC_DEFAULT_ORG}\"
        }
    }" > /dev/null

    # Disable password confirmation as stated at https://github.com/MISP/MISP/issues/8116
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting -q "Security.require_password_confirmation" false
}

set_up_ldap() {
    if [[ "$LDAP_ENABLE" != "true" ]]; then
        echo "... LDAP authentication disabled"
        return
    fi

    # Check required variables
    # LDAP_SEARCH_FILTER may be empty
    check_env_vars LDAP_APACHE_ENV LDAP_SERVER LDAP_STARTTLS LDAP_READER_USER LDAP_READER_PASSWORD LDAP_DN LDAP_SEARCH_ATTRIBUTE LDAP_FILTER LDAP_DEFAULT_ROLE_ID LDAP_DEFAULT_ORG LDAP_OPT_PROTOCOL_VERSION LDAP_OPT_NETWORK_TIMEOUT LDAP_OPT_REFERRALS 

    sudo -u www-data php /var/www/MISP/tests/modify_config.php modify "{
        \"ApacheSecureAuth\": {
            \"apacheEnv\": \"${LDAP_APACHE_ENV}\",
            \"ldapServer\": \"${LDAP_SERVER}\",
            \"starttls\": ${LDAP_STARTTLS},
            \"ldapProtocol\": ${LDAP_OPT_PROTOCOL_VERSION},
            \"ldapNetworkTimeout\": ${LDAP_OPT_NETWORK_TIMEOUT},
            \"ldapReaderUser\": \"${LDAP_READER_USER}\",
            \"ldapReaderPassword\": \"${LDAP_READER_PASSWORD}\",
            \"ldapDN\": \"${LDAP_DN}\",
            \"ldapSearchFilter\": \"${LDAP_SEARCH_FILTER}\",
            \"ldapSearchAttribut\": \"${LDAP_SEARCH_ATTRIBUTE}\",
            \"ldapFilter\": ${LDAP_FILTER},
            \"ldapDefaultRoleId\": ${LDAP_DEFAULT_ROLE_ID},
            \"ldapDefaultOrg\": \"${LDAP_DEFAULT_ORG}\",
            \"ldapAllowReferrals\": ${LDAP_OPT_REFERRALS},
            \"ldapEmailField\": ${LDAP_EMAIL_FIELD}
        }
    }" > /dev/null
}

apply_updates() {
    # Disable weird default
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting -q "Plugin.ZeroMQ_enable" false
    # Run updates (strip colors since output might end up in a log)
    sudo -u www-data /var/www/MISP/app/Console/cake Admin runUpdates | sed -r "s/[[:cntrl:]]\[[0-9]{1,3}m//g"
}

init_user() {
    # Create the main user if it is not there already
    sudo -u www-data /var/www/MISP/app/Console/cake userInit -q 2>&1 > /dev/null

    echo "UPDATE misp.users SET email = \"${ADMIN_EMAIL}\" WHERE id = 1;" | ${MYSQLCMD}

    if [ ! -z "$ADMIN_ORG" ]; then
        echo "UPDATE misp.organisations SET name = \"${ADMIN_ORG}\" where id = 1;" | ${MYSQLCMD}
    fi

    if [ -n "$ADMIN_KEY" ]; then
        echo "... setting admin key to '${ADMIN_KEY}'"
        CHANGE_CMD=(sudo -u www-data /var/www/MISP/app/Console/cake User change_authkey 1 "${ADMIN_KEY}")
    elif [ -z "$ADMIN_KEY" ] && [ "$AUTOGEN_ADMIN_KEY" == "true" ]; then
        echo "... regenerating admin key (set \$ADMIN_KEY if you want it to change)"
        CHANGE_CMD=(sudo -u www-data /var/www/MISP/app/Console/cake User change_authkey 1)
    else
        echo "... admin user key auto generation disabled"
    fi

    if [[ -v CHANGE_CMD[@] ]]; then
        ADMIN_KEY=$("${CHANGE_CMD[@]}" | awk 'END {print $NF; exit}')
        echo "... admin user key set to '${ADMIN_KEY}'"
    fi

    if [ ! -z "$ADMIN_PASSWORD" ]; then
        echo "... setting admin password to '${ADMIN_PASSWORD}'"
        PASSWORD_POLICY=$(sudo -u www-data /var/www/MISP/app/Console/cake Admin getSetting "Security.password_policy_complexity" | jq ".value" -r)
        PASSWORD_LENGTH=$(sudo -u www-data /var/www/MISP/app/Console/cake Admin getSetting "Security.password_policy_length" | jq ".value")
        sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting -q "Security.password_policy_length" 1
        sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting -q "Security.password_policy_complexity" '/.*/'
        sudo -u www-data /var/www/MISP/app/Console/cake User change_pw "${ADMIN_EMAIL}" "${ADMIN_PASSWORD}"
        sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting -q "Security.password_policy_complexity" "${PASSWORD_POLICY}"
        sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting -q "Security.password_policy_length" "${PASSWORD_LENGTH}"
    else
        echo "... setting admin password skipped"
    fi
    echo 'UPDATE misp.users SET change_pw = 0 WHERE id = 1;' | ${MYSQLCMD}
}

apply_critical_fixes() {
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting -q "MISP.external_baseurl" "${BASE_URL}"
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting -q "MISP.host_org_id" 1
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting -q "Plugin.Action_services_enable" false
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting -q "Plugin.Enrichment_hover_enable" false
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting -q "Plugin.Enrichment_hover_popover_only" false
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting -q "Security.csp_enforce" true
    sudo -u www-data php /var/www/MISP/tests/modify_config.php modify "{
        \"Security\": {
            \"rest_client_baseurl\": \"${BASE_URL}\"
        }
    }" > /dev/null
    sudo -u www-data php /var/www/MISP/tests/modify_config.php modify "{
        \"Security\": {
            \"auth\": \"\"
        }
    }" > /dev/null
    # Avoids displaying errors not relevant to a docker container
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting -q "MISP.self_update" false
}

apply_optional_fixes() {
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting -q --force "MISP.welcome_text_top" ""
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting -q --force "MISP.welcome_text_bottom" ""

    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting -q "MISP.contact" "${ADMIN_EMAIL}"
    # This is not necessary because we update the DB directly
    # sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting -q "MISP.org" "${ADMIN_ORG}"

    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting -q "MISP.log_client_ip" true
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting -q "MISP.log_user_ips" true
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting -q "MISP.log_user_ips_authkeys" true

    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting -q "Plugin.Enrichment_timeout" 30
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting -q "Plugin.Enrichment_hover_timeout" 5
}

update_components() {
    sudo -u www-data /var/www/MISP/app/Console/cake Admin updateGalaxies
    sudo -u www-data /var/www/MISP/app/Console/cake Admin updateTaxonomies
    sudo -u www-data /var/www/MISP/app/Console/cake Admin updateWarningLists
    sudo -u www-data /var/www/MISP/app/Console/cake Admin updateNoticeLists
    sudo -u www-data /var/www/MISP/app/Console/cake Admin updateObjectTemplates "$CRON_USER_ID"
}


create_sync_servers() {
    if [ -z "$ADMIN_KEY" ]; then
        echo "... admin key auto configuration is required to configure sync servers"
        return
    fi

    SPLITTED_SYNCSERVERS=$(echo $SYNCSERVERS | tr ',' '\n')
    for ID in $SPLITTED_SYNCSERVERS; do
        DATA="SYNCSERVERS_${ID}_DATA"

        # Validate #1
        NAME=$(echo "${!DATA}" | jq -r '.name')
        if [[ -z $NAME ]]; then
            echo "... error missing sync server name"
            continue
        fi

        # Skip sync server if we can
        echo "... searching sync server ${NAME}"
        SERVER_ID=$(get_server ${BASE_URL} ${ADMIN_KEY} ${NAME})
        if [[ -n "$SERVER_ID" ]]; then
            echo "... found existing sync server ${NAME} with id ${SERVER_ID}"
            continue
        fi

        # Validate #2
        UUID=$(echo "${!DATA}" | jq -r '.remote_org_uuid')
        if [[ -z "$UUID" ]]; then
            echo "... error missing sync server remote_org_uuid"
            continue
        fi

        # Get remote organization
        echo "... searching remote organization ${UUID}"
        ORG_ID=$(get_organization ${BASE_URL} ${ADMIN_KEY} ${UUID})
        if [[ -z "$ORG_ID" ]]; then
            # Add remote organization if missing
            echo "... adding missing organization ${UUID}"
            add_organization ${BASE_URL} ${ADMIN_KEY} ${NAME} false ${UUID} > /dev/null
            ORG_ID=$(get_organization ${BASE_URL} ${ADMIN_KEY} ${UUID})
        fi

        # Add sync server
        echo "... adding new sync server ${NAME} with organization id ${ORG_ID}"
        JSON_DATA=$(echo "${!DATA}" | jq --arg org_id ${ORG_ID} 'del(.remote_org_uuid) | . + {remote_org_id: $org_id}')
        add_server ${BASE_URL} ${ADMIN_KEY} "$JSON_DATA" > /dev/null
    done
}

echo "MISP | Update CA certificates ..." && update-ca-certificates

echo "MISP | Initialize configuration ..." && init_configuration

echo "MISP | Initialize workers ..." && init_workers

echo "MISP | Configure GPG key ..." && configure_gnupg

echo "MISP | Apply updates ..." && apply_updates

echo "MISP | Init default user and organization ..." && init_user

echo "MISP | Resolve critical issues ..." && apply_critical_fixes

echo "MISP | Resolve non-critical issues ..." && apply_optional_fixes

echo "MISP | Create sync servers ..." && create_sync_servers

echo "MISP | Update components ..." && update_components

echo "MISP | Set Up OIDC ..." && set_up_oidc

echo "MISP | Set Up LDAP ..." && set_up_ldap

echo "MISP | Mark instance live"
sudo -u www-data /var/www/MISP/app/Console/cake Admin live 1
