#!/bin/bash
#
# Custom MISP Configuration Script
# This script is executed after MISP initialization is complete
# Use this to customize MISP settings that are not handled by environment variables
#

set -e

echo "Starting custom MISP configuration..."

# Wait for MISP to be fully ready using the same method as readiness probe
echo "Waiting for MISP to be ready..."

# First check basic HTTP response
while ! curl -s -k "${BASE_URL:-https://localhost}/users/heartbeat" > /dev/null; do
    echo "Waiting for MISP HTTP response..."
    sleep 10
done
echo "✓ MISP HTTP is responding"

# Then wait for the readiness log confirmation (same as Kubernetes readiness probe)
echo "Waiting for MISP readiness confirmation..."
max_readiness_wait=60  # 10 minutes max wait
readiness_wait=0

while [ $readiness_wait -lt $max_readiness_wait ]; do
    if grep -i 'MISP is ready' /misp/readiness/ready.log >/dev/null 2>&1; then
        echo "✓ MISP readiness confirmed via ready.log"
        break
    else
        echo "Waiting for MISP readiness confirmation... ($readiness_wait/$max_readiness_wait)"
        sleep 10
        readiness_wait=$((readiness_wait + 1))
    fi
done

if [ $readiness_wait -eq $max_readiness_wait ]; then
    echo "⚠️ Warning: Timeout waiting for readiness confirmation, proceeding anyway..."
fi

echo "MISP is ready, applying custom configurations..."

# Ensure we're in the right directory for cake commands
cd /var/www/MISP

# Additional wait for cake commands to be fully available
echo "Allowing extra time for cake commands to be ready..."
sleep 10

# Example: Set custom MISP settings using the cake command
# Replace these examples with your actual configuration needs
# Function to set MISP settings with cake command (now that MISP is fully ready)
set_misp_setting() {
    local setting_name="$1"
    local setting_value="$2"
    local description="$3"
    
    echo "Setting ${description}: ${setting_name}=${setting_value}"
    
    # Use cake command (should work now since MISP is fully ready)
    if ./app/Console/cake Admin setSetting "${setting_name}" "${setting_value}"; then
        echo "✓ Successfully set ${setting_name} via cake command"
        return 0
    else
        echo "✗ Failed to set ${setting_name} via cake command"
        return 1
    fi
}


# Configuration functions
configure_admin_password() {
    if [ -n "${ADMIN_PASSWORD}" ]; then
        echo "Changing admin user password (User ID: 1)..."
        if ./app/Console/cake user change_pw 1 "${ADMIN_PASSWORD}"; then
            echo "✓ Successfully changed admin password"
            return 0
        fi
    else
        echo "⚠️ ADMIN_PASSWORD not set, skipping password change"
        return 0
    fi
}

configure_background_jobs() {
    set_misp_setting "SimpleBackgroundJobs.enabled" "true" "background jobs enabled"
    set_misp_setting "SimpleBackgroundJobs.supervisor_host" "127.0.0.1" "supervisor host"
    set_misp_setting "SimpleBackgroundJobs.supervisor_port" "9001" "supervisor port"
    set_misp_setting "SimpleBackgroundJobs.supervisor_password" "${SUPERVISOR_PASSWORD}" "supervisor password"
    # set_misp_setting "SimpleBackgroundJobs.supervisor_user" "${SUPERVISOR_USERNAME}" "supervisor user"
    set_misp_setting "SimpleBackgroundJobs.redis_host" "${REDIS_HOST}" "background jobs redis host"
    set_misp_setting "SimpleBackgroundJobs.redis_port" "${REDIS_PORT}" "background jobs redis port"
    # set_misp_setting "SimpleBackgroundJobs.redis_password" "oe2EekeeShufei7yi0" "background jobs redis password (empty for no auth)"
    # set_misp_setting "MISP.redis_password" "oe2EekeeShufei7yi0" "MISP redis password"
    set_misp_setting "SimpleBackgroundJobs.redis_database" "1" "background jobs redis database"
}

# run_custom_python_scripts() {
#     if [ -f "${CUSTOM_PATH:-/custom}/custom_config.py" ]; then
#         echo "Running custom Python configuration..."
#         python3 "${CUSTOM_PATH:-/custom}/custom_config.py"
#     else
#         echo "No custom Python script found at ${CUSTOM_PATH:-/custom}/custom_config.py"
#     fi
# }

# Execute configuration steps
echo "MISP | Change admin password ..." && configure_admin_password
echo "MISP | Configure background jobs ..." && configure_background_jobs
echo "MISP | Restarting workers ..." && supervisorctl -u "${SUPERVISOR_USERNAME}" -p "${SUPERVISOR_PASSWORD}" restart misp-workers:*
# echo "MISP | Run custom Python scripts ..." && run_custom_python_scripts

echo "Custom MISP configuration completed successfully!"