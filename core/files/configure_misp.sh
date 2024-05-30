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
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting -q "MISP.python_bin" $(which python3)
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting -q "MISP.redis_host" "${REDIS_FQDN}"
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting -q "Plugin.ZeroMQ_redis_host" "${REDIS_FQDN}"
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting -q "Plugin.Enrichment_services_url" "${MISP_MODULES_FQDN}"
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting -q "Plugin.Import_services_url" "${MISP_MODULES_FQDN}"
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting -q "Plugin.Export_services_url" "${MISP_MODULES_FQDN}"
    local description="initialisation"
    local settings_json='{
        "MISP.baseurl": {"default_value": "'"${BASE_URL}"'", "command_args": ""},
        "MISP.email": {"default_value": "'"${MISP_EMAIL-$ADMIN_EMAIL}"'", "command_args": ""},
        "MISP.contact": {"default_value": "'"${MISP_CONTACT-$ADMIN_EMAIL}"'", "command_args": ""},
        "MISP.python_bin": {"default_value": "'"$(which python3)"'", "command_args": ""},
        "MISP.redis_host": {"default_value": "'"${REDIS_FQDN}"'", "command_args": ""},
        "Plugin.ZeroMQ_redis_host": {"default_value": "'"${REDIS_FQDN}"'", "command_args": ""},
        "Plugin.Enrichment_services_url": {"default_value": "'"${MISP_MODULES_FQDN}"'", "command_args": ""},
        "Plugin.Import_services_url": {"default_value": "'"${MISP_MODULES_FQDN}"'", "command_args": ""},
        "Plugin.Export_services_url": {"default_value": "'"${MISP_MODULES_FQDN}"'", "command_args": ""},
        "Plugin.Action_services_url": {"default_value": "'"${MISP_MODULES_FQDN}"'", "command_args": ""},
        "MISP.ca_path": {"default_value": "/var/www/MISP/app/Lib/cakephp/lib/Cake/Config/cacert.pem", "command_args": ""},
        "MISP.redis_port": {"default_value": 6379, "command_args": ""},
        "MISP.redis_database": {"default_value": 13, "command_args": ""},
        "MISP.redis_password": {"default_value": "", "command_args": ""},
        "MISP.language": {"default_value": "eng", "command_args": ""},
        "MISP.showorg": {"default_value": true, "command_args": ""},
        "MISP.osuser": {"default_value": "www-data", "command_args": ""},
        "MISP.default_event_distribution": {"default_value": 0, "command_args": ""},
        "MISP.default_event_tag_collection": {"default_value": 0, "command_args": ""},
        "MISP.default_attribute_distribution": {"default_value": "event", "command_args": ""},
        "MISP.proposals_block_attributes": {"default_value": false, "command_args": ""},
        "MISP.background_jobs": {"default_value": true, "command_args": ""},
        "MISP.tagging": {"default_value": true, "command_args": ""},
        "MISP.enableEventBlocklisting": {"default_value": true, "command_args": ""},
        "MISP.enableOrgBlocklisting": {"default_value": true, "command_args": ""},
        "MISP.store_api_access_time": {"default_value": false, "command_args": ""},
        "MISP.log_auth": {"default_value": true, "command_args": ""},
        "MISP.log_new_audit": {"default_value": true, "command_args": ""},
        "MISP.disable_user_login_change": {"default_value": false, "command_args": ""},
        "MISP.incoming_tags_disabled_by_default": {"default_value": false, "command_args": ""},
        "MISP.full_tags_on_event_index": {"default_value": true, "command_args": ""},
        "MISP.event_alert_republish_ban": {"default_value": true, "command_args": ""},
        "MISP.showCorrelationsOnIndex": {"default_value": true, "command_args": ""},
        "MISP.user_email_notification_ban": {"default_value": true, "command_args": ""},
        "MISP.delegation": {"default_value": true, "command_args": ""},
        "MISP.take_ownership_xml_import": {"default_value": false, "command_args": ""},
        "MISP.unpublishedprivate": {"default_value": false, "command_args": ""},
        "MISP.terms_download": {"default_value": false, "command_args": ""},
        "MISP.showorgalternate": {"default_value": false, "command_args": ""},
        "MISP.event_alert_republish_ban_refresh_on_retry": {"default_value": true, "command_args": ""},
        "MISP.event_alert_republish_ban_threshold": {"default_value": 120, "command_args": ""},
        "Plugin.Enrichment_services_enable": {"default_value": true, "command_args": ""},
        "Plugin.Import_services_enable": {"default_value": true, "command_args": ""},
        "Plugin.Export_services_enable": {"default_value": true, "command_args": ""},
        "Plugin.Cortex_services_enable": {"default_value": false, "command_args": ""},
        "Security.advanced_authkeys": {"default_value": true, "command_args": ""},
        "Security.disable_browser_cache": {"default_value": true, "command_args": ""},
        "Security.check_sec_fetch_site_header": {"default_value": true, "command_args": ""},
        "Security.username_in_response_header": {"default_value": true, "command_args": ""},
        "Security.do_not_log_authkeys": {"default_value": true, "command_args": ""},
        "Security.log_each_individual_auth_fail": {"default_value": true, "command_args": ""},
        "Security.alert_on_suspicious_logins": {"default_value": true, "command_args": ""},
        "Security.require_password_confirmation": {"default_value": true, "command_args": ""},
        "SecureAuth.amount": {"default_value": 5, "command_args": ""},
        "SecureAuth.expire": {"default_value": 300, "command_args": ""}
    }'

    process_settings "$settings_json" "$description"
}

init_workers(){
    # Note that we are doing this after enforcing permissions, so we need to use the www-data user for this
    echo "... configuring background workers"
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting -q "SimpleBackgroundJobs.redis_host" "${REDIS_FQDN}"
    local description="worker initialisation"
    local settings_json='{
        "SimpleBackgroundJobs.redis_host": {"default_value": "'"${REDIS_FQDN}"'", "command_args": ""},
        "SimpleBackgroundJobs.enabled": {"default_value": true, "command_args": ""},
        "SimpleBackgroundJobs.supervisor_host": {"default_value": "127.0.0.1", "command_args": ""},
        "SimpleBackgroundJobs.supervisor_port": {"default_value": 9001, "command_args": ""},
        "SimpleBackgroundJobs.supervisor_password": {"default_value": "supervisor", "command_args": ""},
        "SimpleBackgroundJobs.supervisor_user": {"default_value": "supervisor", "command_args": ""},
        "SimpleBackgroundJobs.redis_port": {"default_value": 6379, "command_args": ""},
        "SimpleBackgroundJobs.redis_database": {"default_value": 1, "command_args": ""},
        "SimpleBackgroundJobs.redis_password": {"default_value": "", "command_args": ""},
        "SimpleBackgroundJobs.redis_namespace": {"default_value": "background_jobs", "command_args": ""},
        "SimpleBackgroundJobs.max_job_history_ttl": {"default_value": 86400, "command_args": ""}
    }'

    process_settings "$settings_json" "$description"

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
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting -q "GnuPG.onlyencrypted" false
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting -q "SMIME.enabled" false
}

set_up_oidc() {
    if [[ "$OIDC_ENABLE" != "true" ]]; then
        echo "... OIDC authentication disabled"
        return
    fi

    if [[ -z "$OIDC_ROLES_MAPPING" ]]; then
        OIDC_ROLES_MAPPING="\"\""
    fi

    # Check required variables
    # OIDC_ISSUER may be empty
    check_env_vars OIDC_PROVIDER_URL OIDC_CLIENT_ID OIDC_CLIENT_SECRET OIDC_ROLES_PROPERTY OIDC_ROLES_MAPPING OIDC_DEFAULT_ORG

    sudo -u www-data php /var/www/MISP/tests/modify_config.php modify "{
        \"Security\": {
            \"auth\": [\"OidcAuth.Oidc\"]
        }
    }" > /dev/null

    sudo -u www-data php /var/www/MISP/tests/modify_config.php modify "{
        \"OidcAuth\": {
            \"provider_url\": \"${OIDC_PROVIDER_URL}\",
            ${OIDC_ISSUER:+\"issuer\": \"${OIDC_ISSUER}\",}
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

    # Disable password confirmation as stated at https://github.com/MISP/MISP/issues/8116
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting -q "Security.require_password_confirmation" false
}

set_up_aad() {
    if [[ "$AAD_ENABLE" != "true" ]]; then
        echo "... Entra (AzureAD) authentication disabled"
        return
    fi

    # Check required variables
    check_env_vars AAD_CLIENT_ID AAD_TENANT_ID AAD_CLIENT_SECRET AAD_REDIRECT_URI AAD_PROVIDER AAD_PROVIDER_USER AAD_MISP_ORGADMIN AAD_MISP_SITEADMIN AAD_CHECK_GROUPS

    # Note: Not necessary to edit bootstrap.php to load AadAuth Cake plugin because 
    # existing loadAll() call in bootstrap.php already loads all available Cake plugins

    # Set auth mechanism to AAD in config.php file
    sudo -u www-data php /var/www/MISP/tests/modify_config.php modify "{
        \"Security\": {
            \"auth\": [\"AadAuth.AadAuthenticate\"]
        }
    }" > /dev/null

    # Configure AAD auth settings from environment variables in config.php file
    sudo -u www-data php /var/www/MISP/tests/modify_config.php modify "{
        \"AadAuth\": {
            \"client_id\": \"${AAD_CLIENT_ID}\",
            \"ad_tenant\": \"${AAD_TENANT_ID}\",
            \"client_secret\": \"${AAD_CLIENT_SECRET}\",
            \"redirect_uri\": \"${AAD_REDIRECT_URI}\",
            \"auth_provider\": \"${AAD_PROVIDER}\",
            \"auth_provider_user\": \"${AAD_PROVIDER_USER}\",
            \"misp_user\": \"${AAD_MISP_USER}\",
            \"misp_orgadmin\": \"${AAD_MISP_ORGADMIN}\",
            \"misp_siteadmin\": \"${AAD_MISP_SITEADMIN}\",
            \"check_ad_groups\": ${AAD_CHECK_GROUPS}
        }
    }" > /dev/null

    # Disable self-management, username change, and password change to prevent users from circumventing AAD login flow
    # Recommended per https://github.com/MISP/MISP/blob/2.4/app/Plugin/AadAuth/README.md
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting -q "MISP.disableUserSelfManagement" true
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting -q "MISP.disable_user_login_change" true
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting -q "MISP.disable_user_password_change" true

    # Disable password confirmation as stated at https://github.com/MISP/MISP/issues/8116
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting -q "Security.require_password_confirmation" false
}

apply_updates() {
    # Disable weird default
    process_settings '{"Plugin.ZeroMQ_enable": {"default_value": false, "command_args": ""}}' 'weird default'
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
    sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting -q "Security.rest_client_baseurl" "${BASE_URL}"
    local description="critical"
    local settings_json='{
        "MISP.external_baseurl": {"default_value": "'"${BASE_URL}"'", "command_args": ""},
        "Security.rest_client_baseurl": {"default_value": "'"${BASE_URL}"'", "command_args": ""},
        "MISP.host_org_id": {"default_value": 1, "command_args": ""},
        "MISP.self_update": {"default_value": false, "command_args": ""},
        "Plugin.Action_services_enable": {"default_value": false, "command_args": ""},
        "Plugin.Enrichment_hover_enable": {"default_value": false, "command_args": ""},
        "Plugin.Enrichment_hover_popover_only":  {"default_value": false, "command_args": ""},
        "Security.csp_enforce": {"default_value": true, "command_args": ""},
        "Security.do_not_log_authkeys": {"default_value": true, "command_args": ""}
    }'

    process_settings "$settings_json" "$description"

    local config_json=$(echo '<?php require_once "/var/www/MISP/app/Config/config.php"; echo json_encode($config, JSON_THROW_ON_ERROR | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES); ?>'|/usr/bin/php)

    if  echo $config_json |jq -e 'any(.Security|keys[]; . == "auth")' >/dev/null; then
        echo "Critical array Security.auth is already set. Skipping..."
    else
        echo "Adding missing critical array Security.auth..."
        sudo -u www-data php /var/www/MISP/tests/modify_config.php modify "{
            \"Security\": {
                \"auth\": {}
            }
        }" > /dev/null
    fi
}

apply_optional_fixes() {
    local description="optional"
    local settings_json='{
        "MISP.welcome_text_top": {"default_value": "", "command_args": "-f"},
        "MISP.welcome_text_bottom": {"default_value": "", "command_args": "-f"},
        "MISP.log_client_ip": {"default_value": true, "command_args": ""},
        "MISP.log_user_ips": {"default_value": true, "command_args": ""},
        "MISP.log_user_ips_authkeys": {"default_value": true, "command_args": ""},
        "Plugin.Enrichment_timeout": {"default_value": 30, "command_args": ""},
        "Plugin.Enrichment_hover_timeout": {"default_value": 5, "command_args": ""}
    }'
        # This is not necessary because we update the DB directly
        # "MISP.org": {"default_value": "'"${ADMIN_ORG}"'", "command_args": ""},

    process_settings "$settings_json" "$description"
}

# Some settings return a value from cake Admin getSetting even if not set in config.php and database.
# This means we cannot rely on that tool which inspects both db and file.
# Leaving this here though in case the serverSettings model for those odd settings is fixed one day.
setting_is_set() {
    local setting="$1"
    local current_value="$(sudo -u www-data /var/www/MISP/app/Console/cake Admin getSetting $setting)"
    local error_value="$(jq -r '.errorMessage' <<< $current_value)"

    if [[ "$current_value" =~ ^\{.*\}$ && "$error_value" != "Value not set." && "$error_value" != Invalid* ]]; then
       return 0
    else
       return 1
    fi
}

# Kludgy alternative to using cake Admin getSetting.
setting_is_set_alt() {
    local setting="$1"
    local config_json=$(echo '<?php require_once "/var/www/MISP/app/Config/config.php"; echo json_encode($config, JSON_THROW_ON_ERROR | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES); ?>'|/usr/bin/php)
    local db_settings_enabled=$(jq -e 'getpath(("MISP.system_setting_db" | split("."))) // false' <<< $config_json)
    local setting_in_config_file=$(jq -e 'getpath(("'"$setting"'" | split("."))) != null' <<< $config_json) 
    if $setting_in_config_file; then
        return 0
    elif $db_settings_enabled; then
        local setting_in_db=$(echo "SELECT EXISTS(SELECT 1 FROM misp.system_settings WHERE setting = \"${setting}\");" | ${MYSQLCMD})
        if [[ $setting_in_db -eq 1 ]]; then
            return 0
        fi
    fi
    return 1
}

set_safe_default() {
    local setting="$1"
    local default_value="$2"
    local description="$3"
    local command_args="$4"

    if setting_is_set_alt "$setting"; then
        echo "Skipping already set $description setting '$setting'..."        
    else
        echo "Updating unset $description setting '$setting' to '$default_value'..."
        sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting -q $command_args "$setting" "$default_value"
    fi
}

process_settings() {
    local settings_json="$1"
    local description="$2"

    for setting in $(jq -r 'keys[]' <<< $settings_json); do
        local default_value="$(jq -r '."'"$setting"'"["default_value"]' <<< $settings_json)"
        local command_args="$(jq -r '."'"$setting"'"["command_args"]' <<< $settings_json)"

        set_safe_default "$setting" "$default_value" "$description" "$command_args"
    done
}

update_components() {
    sudo -u www-data /var/www/MISP/app/Console/cake Admin updateGalaxies
    sudo -u www-data /var/www/MISP/app/Console/cake Admin updateTaxonomies
    sudo -u www-data /var/www/MISP/app/Console/cake Admin updateWarningLists
    sudo -u www-data /var/www/MISP/app/Console/cake Admin updateNoticeLists
    sudo -u www-data /var/www/MISP/app/Console/cake Admin updateObjectTemplates "$CRON_USER_ID"
}

update_ca_certificates() {
    # Upgrade host os certificates
    update-ca-certificates
    # Upgrade cake cacert.pem file from Mozilla project
    echo "Updating /var/www/MISP/app/Lib/cakephp/lib/Cake/Config/cacert.pem..."
    sudo -u www-data curl -s --etag-compare /var/www/MISP/app/Lib/cakephp/lib/Cake/Config/etag.txt --etag-save /var/www/MISP/app/Lib/cakephp/lib/Cake/Config/etag.txt https://curl.se/ca/cacert.pem -o /var/www/MISP/app/Lib/cakephp/lib/Cake/Config/cacert.pem
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

echo "MISP | Update CA certificates ..." && update_ca_certificates

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

echo "MISP | Set Up AAD ..." && set_up_aad

echo "MISP | Mark instance live"
sudo -u www-data /var/www/MISP/app/Console/cake Admin live 1
