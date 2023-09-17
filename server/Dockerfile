ARG DOCKER_HUB_PROXY=""

FROM "${DOCKER_HUB_PROXY}debian:bullseye-slim" as composer-build
    ENV DEBIAN_FRONTEND noninteractive
    ENV COMPOSER_ALLOW_SUPERUSER 1
    ARG MISP_TAG
    ARG MISP_COMMIT

    RUN apt-get update; apt-get install -y --no-install-recommends \
        ca-certificates \
        php \
        php-apcu \
        php-curl \
        php-xml \
        php-intl \
        php-bcmath \
        php-mbstring \
        php-mysql \
        php-redis \
        php-gd \
        php-fpm \
        php-zip \
        unzip \
        && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

    WORKDIR /tmp
    ADD https://raw.githubusercontent.com/MISP/MISP/${MISP_COMMIT:-${MISP_TAG}}/app/composer.json /tmp
    COPY --from=composer:latest /usr/bin/composer /usr/bin/composer
    RUN composer config --no-interaction allow-plugins.composer/installers true
    RUN composer install
    RUN composer require --with-all-dependencies --no-interaction \
            supervisorphp/supervisor:^4.0 \
            guzzlehttp/guzzle \
            lstrojny/fxmlrpc \
            php-http/message \
            php-http/message-factory \
            # docker image specific dependencies
            elasticsearch/elasticsearch:^8.7.0 \
            jakub-onderka/openid-connect-php:^1.0.0 \
            aws/aws-sdk-php

FROM "${DOCKER_HUB_PROXY}debian:bullseye-slim" as php-build
    ENV DEBIAN_FRONTEND noninteractive
    ENV TZ Etc/UTC

    RUN apt-get update; apt-get install -y --no-install-recommends \
        gcc \
        g++ \
        make \
        libfuzzy-dev \
        ca-certificates \
        php \
        php-dev \
        php-xml \
        php-pear \
        librdkafka-dev \
        libsimdjson-dev \
        git \
        && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

    RUN cp "/usr/lib/$(gcc -dumpmachine)"/libfuzzy.* /usr/lib; pecl channel-update pecl.php.net && pecl install ssdeep && pecl install rdkafka && pecl install simdjson
    RUN git clone --recursive --depth=1 https://github.com/kjdev/php-ext-brotli.git && \
        cd php-ext-brotli && phpize && ./configure && make && make install

FROM "${DOCKER_HUB_PROXY}debian:bullseye-slim" as python-build
    ENV DEBIAN_FRONTEND noninteractive   
    ARG MISP_TAG
    ARG MISP_COMMIT
    ARG PYPI_REDIS_VERSION
    ARG PYPI_LIEF_VERSION
    ARG PYPI_PYDEEP2_VERSION
    ARG PYPI_PYTHON_MAGIC_VERSION
    ARG PYPI_MISP_LIB_STIX2_VERSION
    ARG PYPI_MAEC_VERSION
    ARG PYPI_MIXBOX_VERSION
    ARG PYPI_CYBOX_VERSION
    ARG PYPI_PYMISP_VERSION

    RUN apt-get update; apt-get install -y --no-install-recommends \
        python3-pip \
        git \
        && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*
    
    # Download MISP using git in the /var/www/ directory. Remove unnecessary items.
    RUN <<-EOF
        if [ ! -z "${MISP_COMMIT}" ]; then
            git clone https://github.com/MISP/MISP.git /var/www/MISP && cd /var/www/MISP && git checkout "${MISP_COMMIT}"
        else
            git clone --branch "${MISP_TAG}" --depth 1 https://github.com/MISP/MISP.git /var/www/MISP
        fi

        cd /var/www/MISP || exit; git submodule update --init --recursive .
EOF

    RUN <<-EOF
        mkdir /wheels

        # Remove modules only used during MISP build
        set -- 'coveralls' 'codecov' 'requests-mock' 'nose' 'pip'
        for mod in "$@"; do
            sed "/${mod}/d" -i /var/www/MISP/requirements.txt
        done;

        # Add additional dependencies (container specific)
        # The "set" line contains the list of modules we want to ensure are present.
        # PYPI_MODULE_NAME_VERSION env vars can be set to specify the version desired,
        # e.g. PYPI_SURICATA_VERSION="==2.0" to specify exactly version 2.0 for the suricata package
        #
        # 1. Check for presence of each module in requirements.txt
        # 2. If missing, add it (with optional version from env (defaults to empty string))
        # 3. If present, replace with our specified version if it exists, otherwise leave
        #    the upstream version alone.
        set -- "redis" "lief" "pydeep2" "python-magic" "misp-lib-stix2" "maec" "mixbox" "cybox" "pymisp"
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

        pip3 wheel --no-cache-dir -w /wheels/ -r /var/www/MISP/requirements.txt
        
        # Remove files we do not care for
        rm -r /var/www/MISP/PyMISP
        find /var/www/MISP/INSTALL/* ! -name 'MYSQL.sql' -type f -exec rm {} +
        find /var/www/MISP/INSTALL/* ! -name 'MYSQL.sql' -type l -exec rm {} +
        # Remove most files in .git - we do not use git functionality in docker
        find /var/www/MISP/.git/* ! -name HEAD -exec rm -rf {} +
EOF

FROM "${DOCKER_HUB_PROXY}debian:bullseye-slim"
    ENV DEBIAN_FRONTEND noninteractive
    ARG MISP_TAG
    ARG MISP_COMMIT
    ARG PHP_VER

    RUN apt-get update; apt-get install -y --no-install-recommends \
        procps \
        sudo \
        nginx \
        supervisor \
        cron \
        openssl \
        gpg \
        gpg-agent \
        ssdeep \
        libfuzzy2 \
        mariadb-client \
        rsync \
        # Python Requirements
        python3 \
        python3-setuptools \
        python3-pip \
        # PHP Requirements
        php \
        php-apcu \
        php-curl \
        php-xml \
        php-intl \
        php-bcmath \
        php-mbstring \
        php-mysql \
        php-redis \
        php-gd \
        php-fpm \
        php-zip \
        librdkafka1 \
        libbrotli1 \
        libsimdjson5 \
        # Unsure we need these
        zip unzip \
        # Require for advanced an unattended configuration
        curl jq \
        && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

    # Install python modules
    COPY --from=python-build /wheels /wheels
    RUN pip3 install --no-cache-dir /wheels/*.whl && rm -rf /wheels

    # PHP: install prebuilt libraries, then install the app's PHP deps
    COPY --from=php-build ["/usr/lib/php/${PHP_VER}/ssdeep.so", "/usr/lib/php/${PHP_VER}/rdkafka.so", "/usr/lib/php/${PHP_VER}/brotli.so", "/usr/lib/php/${PHP_VER}/simdjson.so", "/usr/lib/php/${PHP_VER}/"]

    # Do an early chown to limit image size
    COPY --from=python-build --chown=www-data:www-data --chmod=0550 /var/www/MISP /var/www/MISP
    COPY --from=composer-build --chown=www-data:www-data --chmod=0550 /tmp/Vendor /var/www/MISP/app/Vendor
    COPY --from=composer-build --chown=www-data:www-data --chmod=0550 /tmp/Plugin /var/www/MISP/app/Plugin

    # Gather these in one layer, only act on actual directories under /etc/php/
    RUN <<-EOF
        set -- "ssdeep" "rdkafka" "brotli" "simdjson"
        for mod in "$@"; do
            for dir in /etc/php/*/; do
                echo "extension=${mod}.so" > "${dir}mods-available/${mod}.ini"
            done;
            phpenmod "${mod}"
        done;
        phpenmod redis
EOF

    # nginx
    RUN rm /etc/nginx/sites-enabled/*; mkdir /run/php /etc/nginx/certs

    # Make a copy of the file and configuration stores, so we can sync from it

    # The spirit of the upstream dockerization is to make:
    #   1) User and group aligned in terms of permissions
    #   2) Files executable and read only, because of some rogue scripts like 'cake'
    #   3) Directories writable, because sometimes MISP add new files

    RUN <<-EOF
        cp -R /var/www/MISP/app/files /var/www/MISP/app/files.dist
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
