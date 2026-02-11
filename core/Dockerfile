ARG DOCKER_HUB_PROXY=""


FROM "${DOCKER_HUB_PROXY}python:3.12-slim-trixie" AS php-base
ENV DEBIAN_FRONTEND=noninteractive
ARG CORE_TAG
ARG CORE_COMMIT
ARG PHP_VER
ARG CORE_FLAVOR

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
                sudo \
                nginx \
                openssl \
                gpg \
                gpg-agent \
                mariadb-client \
                rsync \
                rsyslog \
                php8.4 \
                php8.4-curl \
                php8.4-xml \
                php8.4-mbstring \
                php8.4-mysql \
                php8.4-redis \
                php8.4-gd \
                php8.4-fpm \
                php8.4-zip \
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
                sudo \
                nginx \
                openssl \
                gpg \
                gpg-agent \
                mariadb-client \
                rsync \
                rsyslog \
                php8.4 \
                php8.4-apcu \
                php8.4-curl \
                php8.4-xml \
                php8.4-intl \
                php8.4-bcmath \
                php8.4-mbstring \
                php8.4-mysql \
                php8.4-redis \
                php8.4-gd \
                php8.4-fpm \
                php8.4-zip \
                php8.4-ldap \
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

FROM php-base AS composer-build
ENV COMPOSER_ALLOW_SUPERUSER=1

WORKDIR /tmp
RUN curl -o /tmp/composer.json https://raw.githubusercontent.com/MISP/MISP/${CORE_COMMIT:-${CORE_TAG}}/app/composer.json
RUN sed -i '/cake-resque/d' /tmp/composer.json
RUN sed -i 's/authentication",/authentication"/' /tmp/composer.json

COPY --from=composer:latest /usr/bin/composer /usr/bin/composer
RUN composer config --no-interaction allow-plugins.composer/installers true
RUN composer install
RUN <<-EOF
        if [ "${CORE_FLAVOR}" = "slim" ]; then
            :
        else
            composer require --with-all-dependencies --no-interaction \
                elasticsearch/elasticsearch:^8.7.0 \
                jakub-onderka/openid-connect-php:^1.0.0 \
                certmichelin/openid-connect-php:1.3.0 \
                aws/aws-sdk-php
        fi
EOF


FROM php-base AS php-build
ENV TZ=Etc/UTC

RUN <<-EOF
        if [ "${CORE_FLAVOR}" = "slim" ]; then
            apt-get install -y --no-install-recommends \
                gcc \
                g++ \
                git \
                make \
                php8.4-dev \
                php-pear
        else
            apt-get install -y --no-install-recommends \
                gcc \
                g++ \
                git \
                make \
                php8.4-dev \
                php-pear \
                libbrotli-dev \
                libfuzzy-dev \
                librdkafka-dev \
                libsimdjson-dev \
                libzstd-dev
        fi
        apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*
EOF

RUN update-alternatives --set php /usr/bin/php8.4
RUN update-alternatives --set php-config /usr/bin/php-config8.4
RUN update-alternatives --set phpize /usr/bin/phpize8.4

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
                /usr/lib/php/${PHP_VER}/ssdeep.so \
                /usr/lib/php/${PHP_VER}/rdkafka.so \
                /usr/lib/php/${PHP_VER}/brotli.so \
                /usr/lib/php/${PHP_VER}/simdjson.so \
                /usr/lib/php/${PHP_VER}/zstd.so
        fi
EOF


FROM php-base AS python-build
ARG PYPI_REDIS_VERSION
ARG PYPI_LIEF_VERSION
ARG PYPI_PYDEEP2_VERSION
ARG PYPI_PYTHON_MAGIC_VERSION
ARG PYPI_MISP_LIB_STIX2_VERSION
ARG PYPI_MAEC_VERSION
ARG PYPI_MIXBOX_VERSION
ARG PYPI_CYBOX_VERSION
ARG PYPI_PYMISP_VERSION
ARG PYPI_MISP_STIX_VERSION
ARG PYPI_TAXII2_CLIENT
ARG PYPI_SETUPTOOLS_VERSION
ARG PYPI_SUPERVISOR_VERSION

RUN apt-get install -y --no-install-recommends \
    git \
    && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Download MISP using git in the /var/www/ directory. Remove unnecessary items.
RUN <<-EOF
        if [ ! -z "${CORE_COMMIT}" ]; then
            git clone https://github.com/MISP/MISP.git /var/www/MISP && cd /var/www/MISP && git checkout "${CORE_COMMIT}"
        else
            git clone --branch "${CORE_TAG}" --depth 1 https://github.com/MISP/MISP.git /var/www/MISP
        fi
        cd /var/www/MISP || exit; git submodule update --init --recursive .
EOF

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
        set -- "redis" "lief" "pydeep2" "python-magic" "misp-lib-stix2" "maec" "mixbox" "cybox" "pymisp" "misp-stix" "taxii2-client" "setuptools" "supervisor"
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


FROM php-base

# Remove some defaults (kernel logging) and fix alternatives
RUN sed -i '/imklog/s/^/#/' /etc/rsyslog.conf
RUN update-alternatives --set php /usr/bin/php8.4
RUN apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Install python modules
COPY --from=python-build /wheels /wheels
RUN pip install --no-cache-dir /wheels/*.whl && rm -rf /wheels
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

# nginx
RUN rm /etc/nginx/sites-enabled/*; mkdir -p /run/php /etc/nginx/certs

# Make a copy of the file and configuration stores, so we can sync from it

# The spirit of the upstream dockerization is to make:
#   1) User and group aligned in terms of permissions
#   2) Files executable and read only, because of some rogue scripts like 'cake'
#   3) Directories writable, because sometimes MISP add new files

RUN <<-EOF
        cp -R /var/www/MISP/app/files /var/www/MISP/app/files.dist
        echo "${CORE_COMMIT:-${CORE_TAG}}" > /var/www/MISP/app/files/VERSION
        cp -R /var/www/MISP/app/Config /var/www/MISP/app/Config.dist
        find /var/www/MISP \( ! -user www-data -or ! -group www-data \) -exec chown www-data:www-data '{}' +;
        find /var/www/MISP -not -perm 550 -type f -exec chmod 0550 '{}' +;
        find /var/www/MISP -not -perm 770 -type d -exec chmod 0770 '{}' +;
        # Diagnostics wants this file to be present and writable even if we do not use git in docker land
        touch /var/www/MISP/.git/ORIG_HEAD && chmod 0600 /var/www/MISP/.git/ORIG_HEAD && chown www-data:www-data /var/www/MISP/.git/ORIG_HEAD
EOF

# Copy all our image specific files to appropriate locations
COPY files/ /
ENTRYPOINT [ "/entrypoint.sh" ]

# Change Workdirectory
WORKDIR /var/www/MISP
