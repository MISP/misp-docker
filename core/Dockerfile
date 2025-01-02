ARG DOCKER_HUB_PROXY=""


FROM "${DOCKER_HUB_PROXY}ubuntu:24.04" AS php-base
    ENV DEBIAN_FRONTEND noninteractive

    # Uncomment when building in corporate environments
    # COPY ./cert.pem /usr/local/share/ca-certificates/rootca.pem
    # COPY ./cert.pem /usr/lib/ssl/cert.pem

    RUN apt-get update; apt-get install -y --no-install-recommends \
        lsb-release \
        ca-certificates \
        curl


FROM php-base AS composer-build
    ENV DEBIAN_FRONTEND noninteractive
    ENV COMPOSER_ALLOW_SUPERUSER 1
    ARG CORE_TAG
    ARG CORE_COMMIT
    ARG TARGETPLATFORM

    RUN apt-get install -y --no-install-recommends \
        php8.3 \
        php8.3-apcu \
        php8.3-curl \
        php8.3-xml \
        php8.3-intl \
        php8.3-bcmath \
        php8.3-mbstring \
        php8.3-mysql \
        php8.3-redis \
        php8.3-gd \
        php8.3-fpm \
        php8.3-zip \
        unzip \
        && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

    WORKDIR /tmp
    RUN curl -o /tmp/composer.json https://raw.githubusercontent.com/MISP/MISP/${CORE_COMMIT:-${CORE_TAG}}/app/composer.json
    COPY --from=composer:2.7.7 /usr/bin/composer /usr/bin/composer

    # See:
    #   - https://github.com/curl/curl/issues/14154
    #   - https://bugs.launchpad.net/ubuntu/+source/curl/+bug/2073448
    RUN <<-EOF
        if [ "$TARGETPLATFORM" = "linux/arm64" ]; then
            cp /usr/bin/composer /composer.phar
            mkdir /out/
            php -r '$phar = new Phar("/composer.phar"); $phar->extractTo("/out/");'
            sed -i "/'verify_peer_name' =>.*/a 'verify_peer_status' => CURLOPT_SSL_VERIFYSTATUS," /out/src/Composer/Util/Http/CurlDownloader.php
            sed -i "/\$options = StreamContextFactory.*/a \$options['ssl']['verify_peer'] = false;" /out/src/Composer/Util/Http/CurlDownloader.php
            sed -i "/\$options = StreamContextFactory.*/a \$options['ssl']['verify_peer_name'] = false;" /out/src/Composer/Util/Http/CurlDownloader.php
            sed -i "/\$options = StreamContextFactory.*/a \$options['ssl']['verify_peer_status'] = false;" /out/src/Composer/Util/Http/CurlDownloader.php
            rm /usr/bin/composer
            ln -s /out/bin/composer /usr/bin/composer
        fi
EOF

    RUN php /usr/bin/composer config --no-interaction allow-plugins.composer/installers true
    RUN php /usr/bin/composer install
    RUN php /usr/bin/composer require --with-all-dependencies --no-interaction \
        elasticsearch/elasticsearch:^8.7.0 \
        jakub-onderka/openid-connect-php:^1.0.0 \
        aws/aws-sdk-php


FROM php-base AS php-build
    ENV DEBIAN_FRONTEND noninteractive
    ENV TZ Etc/UTC

    RUN apt-get install -y --no-install-recommends \
        gcc \
        g++ \
        git \
        make \
        php8.3 \
        php8.3-dev \
        php8.3-xml \
        php-pear \
        libbrotli-dev \
        libfuzzy-dev \
        librdkafka-dev \
        libsimdjson-dev \
        libzstd-dev \
        && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

    RUN update-alternatives --set php /usr/bin/php8.3
    RUN update-alternatives --set php-config /usr/bin/php-config8.3
    RUN update-alternatives --set phpize /usr/bin/phpize8.3

    RUN cp "/usr/lib/$(gcc -dumpmachine)"/libfuzzy.* /usr/lib
    RUN pecl channel-update pecl.php.net && \
        pecl install rdkafka && \
        pecl install simdjson && \
        pecl install zstd && \
        pecl install brotli

    # install pecl-text-ssdeep 1.2
    RUN git clone --recursive --depth=1 https://github.com/JakubOnderka/pecl-text-ssdeep.git /tmp/pecl-text-ssdeep
    RUN cd /tmp/pecl-text-ssdeep && phpize && ./configure && make && make install

FROM php-base AS python-build
    ENV DEBIAN_FRONTEND noninteractive   
    ARG CORE_TAG
    ARG CORE_COMMIT
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

    RUN apt-get install -y --no-install-recommends \
        git \
        python3-pip \
        python3-wheel \
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
        set -- "redis" "lief" "pydeep2" "python-magic" "misp-lib-stix2" "maec" "mixbox" "cybox" "pymisp" "misp-stix"
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
    ENV DEBIAN_FRONTEND noninteractive
    ARG CORE_TAG
    ARG CORE_COMMIT
    ARG PHP_VER

    RUN apt-get install -y --no-install-recommends \
        gettext \
        procps \
        sudo \
        nginx \
        supervisor \
        cron \
        openssl \
        gpg \
        gpg-agent \
        mariadb-client \
        rsync \
        python3-setuptools \
        python3-pip \
        python3-wheel \
        # PHP Requirements
        php8.3 \
        php8.3-apcu \
        php8.3-curl \
        php8.3-xml \
        php8.3-intl \
        php8.3-bcmath \
        php8.3-mbstring \
        php8.3-mysql \
        php8.3-redis \
        php8.3-gd \
        php8.3-fpm \
        php8.3-zip \
        php8.3-ldap \
        libmagic1 \
        libldap-common \
        librdkafka1 \
        libbrotli1 \
        libsimdjson19 \
        libzstd1 \
        ssdeep \
        libfuzzy2 \
        # Unsure we need these
        zip unzip \
        # Require for advanced an unattended configuration
        curl jq \
        && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

    RUN update-alternatives --set php /usr/bin/php8.3

    # Install python modules
    COPY --from=python-build /wheels /wheels
    RUN pip install --break-system-packages --no-cache-dir /wheels/*.whl && rm -rf /wheels

    # PHP: install prebuilt libraries, then install the app's PHP deps
    COPY --from=php-build ["/usr/lib/php/${PHP_VER}/ssdeep.so", "/usr/lib/php/${PHP_VER}/rdkafka.so", "/usr/lib/php/${PHP_VER}/brotli.so", "/usr/lib/php/${PHP_VER}/simdjson.so", "/usr/lib/php/${PHP_VER}/zstd.so", "/usr/lib/php/${PHP_VER}/"]

    # Do an early chown to limit image size
    COPY --from=python-build --chown=www-data:www-data --chmod=0550 /var/www/MISP /var/www/MISP
    COPY --from=composer-build --chown=www-data:www-data --chmod=0550 /tmp/composer.lock /var/www/MISP/app/composer.lock
    COPY --from=composer-build --chown=www-data:www-data --chmod=0550 /tmp/Vendor /var/www/MISP/app/Vendor
    COPY --from=composer-build --chown=www-data:www-data --chmod=0550 /tmp/Plugin /var/www/MISP/app/Plugin

    # 'setuptools' is needed at runtime by 'mixbox'
    RUN cp /usr/lib/python3/dist-packages/setuptools/_distutils/version.py \
        /usr/local/lib/python3.12/dist-packages/mixbox/distutils_version.py
    RUN sed -i 's/from distutils\.version/from mixbox.distutils_version/' \
        /usr/local/lib/python3.12/dist-packages/mixbox/parser.py
    RUN apt-get remove --purge python3-pip python3-wheel python3-setuptools -y

    # Gather these in one layer, only act on actual directories under /etc/php/
    RUN <<-EOF
        set -- "ssdeep" "rdkafka" "brotli" "simdjson" "zstd"
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
