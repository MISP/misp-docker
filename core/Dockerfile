ARG DOCKER_HUB_PROXY=""

# --- php-base
FROM "${DOCKER_HUB_PROXY}python:3.14-slim-trixie" AS php-base

ARG CORE_TAG
ARG CORE_COMMIT
ARG CORE_FLAVOR
ARG PHP_API_VERSION
RUN : "${PHP_API_VERSION:?Build argument PHP_API_VERSION is required and cannot be empty.}"
ARG PHP_PACKAGE_VERSION
RUN : "${PHP_PACKAGE_VERSION:?Build argument PHP_PACKAGE_VERSION is required and cannot be empty.}"

# environment
ENV DEBIAN_FRONTEND=noninteractive

# Uncomment when building in corporate environments
# COPY ./cert.pem /usr/local/share/ca-certificates/rootca.pem
# COPY ./cert.pem /usr/lib/ssl/cert.pem

RUN <<-EOF
    apt-get update

    if [ "${CORE_FLAVOR}" = "slim" ]; then
        apt-get install -y --no-install-recommends \
            lsb-release \
            ca-certificates \
            tini \
            gettext \
            procps \
            openssl \
            gpg \
            gpg-agent \
            mariadb-client \
            rsync \
            rsyslog \
            libnss-wrapper \
            php${PHP_PACKAGE_VERSION} \
            php${PHP_PACKAGE_VERSION}-curl \
            php${PHP_PACKAGE_VERSION}-xml \
            php${PHP_PACKAGE_VERSION}-mbstring \
            php${PHP_PACKAGE_VERSION}-mysql \
            php${PHP_PACKAGE_VERSION}-redis \
            php${PHP_PACKAGE_VERSION}-gd \
            php${PHP_PACKAGE_VERSION}-fpm \
            php${PHP_PACKAGE_VERSION}-zip \
            unzip \
            zip \
            curl \
            uuid-runtime \
            jq
    else
        apt-get install -y --no-install-recommends \
            lsb-release \
            ca-certificates \
            tini \
            gettext \
            procps \
            openssl \
            gpg \
            gpg-agent \
            mariadb-client \
            rsync \
            rsyslog \
            libnss-wrapper \
            php${PHP_PACKAGE_VERSION} \
            php${PHP_PACKAGE_VERSION}-apcu \
            php${PHP_PACKAGE_VERSION}-curl \
            php${PHP_PACKAGE_VERSION}-xml \
            php${PHP_PACKAGE_VERSION}-intl \
            php${PHP_PACKAGE_VERSION}-bcmath \
            php${PHP_PACKAGE_VERSION}-mbstring \
            php${PHP_PACKAGE_VERSION}-mysql \
            php${PHP_PACKAGE_VERSION}-redis \
            php${PHP_PACKAGE_VERSION}-gd \
            php${PHP_PACKAGE_VERSION}-fpm \
            php${PHP_PACKAGE_VERSION}-zip \
            php${PHP_PACKAGE_VERSION}-ldap \
            libmagic1 \
            libldap-common \
            librdkafka1 \
            libbrotli1 \
            libsimdjson25 \
            libzstd1 \
            ssdeep \
            stunnel4 \
            libfuzzy2 \
            unzip \
            zip \
            curl \
            uuid-runtime \
            jq
    fi
EOF

# --- composer-build
FROM php-base AS composer-build

# environment
WORKDIR /tmp
ENV COMPOSER_ALLOW_SUPERUSER=1
ARG CORE_TAG
ARG CORE_COMMIT
ARG CORE_FLAVOR

# prepare composer.json
RUN curl -o /tmp/composer.json https://raw.githubusercontent.com/MISP/MISP/${CORE_COMMIT:-${CORE_TAG}}/app/composer.json && \
    sed -i '/cake-resque/d' /tmp/composer.json && \
    sed -i 's/authentication",/authentication"/' /tmp/composer.json

# inject composer binary
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# install dependencies
RUN <<-EOF
    composer config --no-interaction allow-plugins.composer/installers true
    composer install

    if [ "${CORE_FLAVOR}" = "slim" ]; then
        :
    else
        composer require --with-all-dependencies --no-interaction \
            elasticsearch/elasticsearch:^8.7.0 \
            jakub-onderka/openid-connect-php:^1.0.0 \
            certmichelin/openid-connect-php:1.3.0 \
            phpseclib/phpseclib:^3.0.47 \
            aws/aws-sdk-php
    fi
EOF

# --- php-build
FROM php-base AS php-build

# environment
ENV TZ=Etc/UTC
ARG CORE_TAG
ARG CORE_COMMIT
ARG CORE_FLAVOR
ARG PHP_API_VERSION

RUN <<-EOF
    if [ "${CORE_FLAVOR}" = "slim" ]; then
        apt-get install -y --no-install-recommends \
            gcc \
            g++ \
            git \
            make \
            php${PHP_PACKAGE_VERSION}-dev \
            php-pear
    else
        apt-get install -y --no-install-recommends \
            gcc \
            g++ \
            git \
            make \
            php${PHP_PACKAGE_VERSION}-dev \
            php-pear \
            libbrotli-dev \
            libfuzzy-dev \
            librdkafka-dev \
            libsimdjson-dev \
            libzstd-dev
    fi
    apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*
EOF

# configure alternatives for php
RUN update-alternatives --set php /usr/bin/php${PHP_PACKAGE_VERSION} && \
    update-alternatives --set php-config /usr/bin/php-config${PHP_PACKAGE_VERSION} && \
    update-alternatives --set phpize /usr/bin/phpize${PHP_PACKAGE_VERSION}

RUN <<-EOF
    pecl channel-update pecl.php.net

    if [ "${CORE_FLAVOR}" = "slim" ]; then
        tar -czf /pecl_libs.tar.gz -T /dev/null
    else
        cp "/usr/lib/$(gcc -dumpmachine)"/libfuzzy.* /usr/lib
        pecl install rdkafka
        pecl install simdjson
        pecl install zstd
        pecl install brotli
        git clone --recursive --depth=1 https://github.com/JakubOnderka/pecl-text-ssdeep.git /tmp/pecl-text-ssdeep
        cd /tmp/pecl-text-ssdeep && phpize && ./configure && make && make install
        tar -czf /pecl_libs.tar.gz \
            /usr/lib/php/${PHP_API_VERSION}/ssdeep.so \
            /usr/lib/php/${PHP_API_VERSION}/rdkafka.so \
            /usr/lib/php/${PHP_API_VERSION}/brotli.so \
            /usr/lib/php/${PHP_API_VERSION}/simdjson.so \
            /usr/lib/php/${PHP_API_VERSION}/zstd.so
    fi
EOF

# --- python-build
FROM php-base AS python-build
ARG CORE_TAG
ARG CORE_COMMIT
ARG CORE_FLAVOR

RUN apt-get install -y --no-install-recommends \
    gcc \
    g++ \
    git \
    make \
    libfuzzy-dev \
    && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Download MISP using git in the /var/www/ directory. Remove unnecessary items.
RUN <<-EOF
    if [ ! -z "${CORE_COMMIT}" ]; then
        git clone https://github.com/MISP/MISP.git /var/www/MISP && cd /var/www/MISP && git checkout "${CORE_COMMIT}"
    else
        git clone --branch "${CORE_TAG}" --depth 1 https://github.com/MISP/MISP.git /var/www/MISP
    fi
    cd /var/www/MISP || exit; git submodule update --init --recursive --depth 1 .

    # v2.5.47 ships two workflow modules declaring the same $id
    # ("send-report-to-cti-info-extractor"), which makes Workflow's module
    # scanner throw WorkflowDuplicatedModuleIDException on every load
    # (surfaces as a 500 on /servers/serverSettings). Fixed upstream in
    # MISP/MISP@1072b37f ("Rework the CTIInfoExtractor workflow action into
    # Summarise report with AI"), which superseded this exact file with
    # Module_ai_summarize_report.php - that commit landed after this tag was
    # cut, so remove the stale duplicate ourselves until a later CORE_TAG
    # picks up the real fix.
    rm -f /var/www/MISP/app/Model/WorkflowModules/action/Module_send_report_to_CTIInfoExtractor.php
EOF

ARG PYPI_SETUPTOOLS_VERSION
RUN : "${PYPI_SETUPTOOLS_VERSION:?Build argument PYPI_SETUPTOOLS_VERSION is required and cannot be empty.}"
ARG PYPI_SUPERVISOR_VERSION
RUN : "${PYPI_SUPERVISOR_VERSION:?Build argument PYPI_SUPERVISOR_VERSION is required and cannot be empty.}"
ARG PYPI_JSONSCHEMA_VERSION
ARG PYPI_LIEF_VERSION
ARG PYPI_MISP_STIX_VERSION
ARG PYPI_PLYARA_VERSION
ARG PYPI_PYDEEP2_VERSION
ARG PYPI_PYMISP_VERSION
ARG PYPI_PYTHON_MAGIC_VERSION
ARG PYPI_PYZMQ_VERSION
ARG PYPI_REDIS_VERSION
ARG PYPI_TAXII2_CLIENT_VERSION
RUN <<-EOF
    mkdir /wheels

    # Add additional dependencies (container specific)
    # The "set" line contains the list of modules we want to ensure are present.
    # PYPI_MODULE_NAME_VERSION env vars can be set to specify the version desired,
    # e.g. PYPI_SURICATA_VERSION="==2.0" to specify exactly version 2.0 for the suricata package
    #
    # 1. Check for presence of each module in requirements.txt
    # 2. If missing, add it (with optional version from env (defaults to empty string))
    # 3. If present, replace with our specified version if it exists, otherwise leave
    #    the upstream version alone.
    set -- "jsonschema" "lief" "misp-stix" "plyara" "pydeep2" "pymisp" "python-magic" "pyzmq" "redis" "taxii2-client" "setuptools" "supervisor"
    for mod in "$@"; do
        mod_version_var=$(echo "PYPI_${mod}_VERSION" | tr '[:lower:]' '[:upper:]' | tr '-' '_')
        mod_version=$(eval "echo \"\$$mod_version_var\"")
        grep -q ${mod} /var/www/MISP/requirements.txt
        exists=$?
        if [ "${exists}" -eq "1" ]; then
            echo "Adding missing module ${mod} with version '${mod_version}'"
            echo ${mod}${mod_version} >> /var/www/MISP/requirements.txt
        else
            if [ "$(echo ${mod_version} | wc -m)" -gt 1 ]; then
                echo "Overwriting existing module ${mod}, version '${mod_version}'"
                sed -i "/${mod}/s/.*/${mod}${mod_version}/" /var/www/MISP/requirements.txt
            else
                echo "Skipping overwriting ${mod} due to missing version variable"
            fi
        fi
    done;

    pip wheel --no-cache-dir -w /wheels/ -r /var/www/MISP/requirements.txt

    # Remove files we do not care for
    find /var/www/MISP/INSTALL/* ! -name 'MYSQL.sql' -type f -exec rm {} +
    find /var/www/MISP/INSTALL/* ! -name 'MYSQL.sql' -type l -exec rm {} +
    # Remove most files in .git - we do not use git functionality in docker
    find /var/www/MISP/.git/* ! -name HEAD -exec rm -rf {} +
    # Remove libraries submodules
    rm -r /var/www/MISP/PyMISP
    rm -r /var/www/MISP/app/files/scripts/cti-python-stix2
    rm -r /var/www/MISP/app/files/scripts/misp-stix
    rm -r /var/www/MISP/app/files/scripts/mixbox
    rm -r /var/www/MISP/app/files/scripts/python-cybox
    rm -r /var/www/MISP/app/files/scripts/python-maec
    rm -r /var/www/MISP/app/files/scripts/python-stix
EOF

# --- final stage
FROM php-base
ARG CORE_TAG
ARG CORE_COMMIT
ARG CORE_FLAVOR

ENV PATH="/var/www/MISP/app/Console:${PATH}"

# Remove some defaults (kernel logging, local syslog socket) and fix
# alternatives. imuxsock binds /dev/log, which needs root/a writable /dev
# - not available to us anymore (and not baked-in-image fixable, since
# /dev is runtime-mounted). Nothing in this container relies on local
# syslog delivery, so rsyslogd just idles harmlessly without it.
RUN sed -i -e '/imklog/s/^/#/' -e '/imuxsock/s/^/#/' /etc/rsyslog.conf
RUN update-alternatives --set php /usr/bin/php${PHP_PACKAGE_VERSION}
RUN ln -sf /usr/sbin/php-fpm${PHP_PACKAGE_VERSION} /usr/local/sbin/php-fpm
RUN apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# www-data (uid 33) is the default runtime identity for Docker/Compose.
# Also make it a member of group 0 so it behaves the same way an
# OpenShift-assigned arbitrary UID would (arbitrary UIDs always carry
# primary group 0) - this keeps the default case and the arbitrary-UID
# case relying on the exact same on-disk permissions.
RUN usermod -aG 0 www-data

# Install python modules.
#
# The wheels are bind-mounted rather than COPYed. A COPY commits them to their own
# layer, and the `rm -rf /wheels` that used to follow could only write a whiteout on
# top of that layer -- it cannot remove the layer from the image, so the wheels
# shipped in everything we publish. A bind mount is never committed to a layer.
RUN --mount=type=bind,from=python-build,source=/wheels,target=/wheels \
    pip install --no-cache-dir /wheels/*.whl
# PHP: install prebuilt libraries, then install the app's PHP deps
COPY --from=php-build /pecl_libs.tar.gz /
RUN tar -xzf /pecl_libs.tar.gz && rm /pecl_libs.tar.gz

# Do an early chown to limit image size
COPY --from=python-build --chown=www-data:www-data --chmod=0550 /var/www/MISP /var/www/MISP
COPY --from=composer-build --chown=www-data:www-data --chmod=0550 /tmp/composer.lock /var/www/MISP/app/composer.lock
COPY --from=composer-build --chown=www-data:www-data --chmod=0550 /tmp/Vendor /var/www/MISP/app/Vendor
COPY --from=composer-build --chown=www-data:www-data --chmod=0550 /tmp/Plugin /var/www/MISP/app/Plugin

# Gather these in one layer, only act on actual directories under /etc/php/
RUN <<-EOF
    if [ "${CORE_FLAVOR}" = "slim" ]; then
        set --
    else
        set -- "ssdeep" "rdkafka" "brotli" "simdjson" "zstd"
    fi
    for mod in "$@"; do
        for dir in /etc/php/*/; do
            echo "extension=${mod}.so" > "${dir}mods-available/${mod}.ini"
        done;
        phpenmod "${mod}"
    done;
    phpenmod redis
EOF

# Make a copy of the file and configuration stores, so we can sync from it

# The spirit of the upstream dockerization is to make:
#   1) User and group aligned in terms of permissions
#   2) Files executable and read only, because of some rogue scripts like 'cake'
#   3) Directories writable, because sometimes MISP add new files
#
# Everything is also group-owned by 0 with group perms mirroring owner
# perms (already true: 0550 files/0770 dirs have group == owner bits) and
# setgid on directories, so it keeps working when OpenShift runs the
# container under an arbitrary UID (always paired with primary group 0).

RUN <<-EOF
    cp -R /var/www/MISP/app/files /var/www/MISP/app/files.dist
    cp -R /var/www/MISP/app/Config /var/www/MISP/app/Config.dist
    echo "${CORE_COMMIT:-${CORE_TAG}}" > /var/www/MISP/app/files/VERSION
    find /var/www/MISP \( ! -user www-data -or ! -group 0 \) -exec chown www-data:0 '{}' +;
    find /var/www/MISP -not -perm 550 -type f -exec chmod 0550 '{}' +;
    find /var/www/MISP -not -perm 2770 -type d -exec chmod 2770 '{}' +;
    # Diagnostics wants this file to be present and writable even if we do not use git in docker land
    touch /var/www/MISP/.git/ORIG_HEAD && chmod 0600 /var/www/MISP/.git/ORIG_HEAD && chown www-data:0 /var/www/MISP/.git/ORIG_HEAD
EOF

# Same treatment for every other system path the entrypoint chain writes
# to at runtime (php-fpm, supervisord, rsyslog) - none of this can be
# chown'd at container startup anymore since we never run as root, so it
# all has to be correct at build time. /var/log covers rsyslog's default
# targets (syslog, auth.log, ...) too. nginx no longer lives in this
# image (see nginx/Dockerfile), which already runs on the
# arbitrary-UID-ready nginx-unprivileged base image.
RUN <<-EOF
    mkdir -p /run/php /var/log/supervisor
    chown -R www-data:0 /run/php /var/log /var/log/supervisor /etc/php/*/fpm /etc/php/*/cli
    chmod -R g=u /run/php /var/log /var/log/supervisor /etc/php/*/fpm /etc/php/*/cli
    find /run/php /var/log /var/log/supervisor /etc/php/*/fpm /etc/php/*/cli -type d -exec chmod g+s '{}' +
EOF

# Copy all our image specific files to appropriate locations
COPY files/ /

# files/ was copied in as root:root, overwriting the ownership/group we
# set on /etc/supervisor above for the pieces it touches (supervisor
# confs) - redo it.
RUN <<-EOF
    chown -R www-data:0 /var/log/supervisor /etc/supervisor
    chmod -R g=u /var/log/supervisor /etc/supervisor
    find /var/log/supervisor /etc/supervisor -type d -exec chmod g+s '{}' +
    # unix_http_server's "file" and supervisord's "pidfile" are the
    # socket/pidfile paths themselves; supervisorctl's "serverurl"
    # (used by configure_misp.sh to start the worker programs) must
    # point at the same relocated socket or it silently fails to
    # connect and the (autostart=false) workers never start.
    sed -i -E 's#^(file|pidfile)=/var/run/#\1=/tmp/#' /etc/supervisor/supervisord.conf
    sed -i -E 's#^(serverurl=unix://)/var/run/#\1/tmp/#' /etc/supervisor/supervisord.conf
EOF

# define entrypoint
ENTRYPOINT [ "/entrypoint.sh" ]

# Default runtime identity for Docker/Compose (OpenShift overrides this
# with its own arbitrary UID regardless of what's declared here).
USER 33

# Change Workdirectory
WORKDIR /var/www/MISP
