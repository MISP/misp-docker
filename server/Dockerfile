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
        && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*
    
    WORKDIR /tmp
    ADD https://raw.githubusercontent.com/MISP/MISP/${MISP_COMMIT:-${MISP_TAG}}/app/composer.json /tmp
    COPY --from=composer:latest /usr/bin/composer /usr/bin/composer
    RUN composer config --no-interaction allow-plugins.composer/installers true
    RUN composer install
    RUN composer require --with-all-dependencies \
            supervisorphp/supervisor:^4.0 \
            guzzlehttp/guzzle \
            lstrojny/fxmlrpc \
            php-http/message \
            php-http/message-factory
    RUN composer require --with-all-dependencies \
            elasticsearch/elasticsearch:^8.7.0 \
            jakub-onderka/openid-connect-php:^1.0.0 \
            aws/aws-sdk-php

FROM "${DOCKER_HUB_PROXY}debian:bullseye-slim" as php-build
    ENV DEBIAN_FRONTEND noninteractive
    RUN apt-get update; apt-get install -y --no-install-recommends \
        gcc \
        g++ \
        make \
        libfuzzy-dev \
        ca-certificates \
        php \
        php-dev \
        php-pear \
        librdkafka-dev \
        libsimdjson-dev \
        git \
        && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

    RUN pecl channel-update pecl.php.net
    RUN cp "/usr/lib/$(gcc -dumpmachine)"/libfuzzy.* /usr/lib; pecl install ssdeep && pecl install rdkafka && pecl install simdjson
    RUN git clone --recursive --depth=1 https://github.com/kjdev/php-ext-brotli.git && \
        cd php-ext-brotli && phpize && ./configure && make && make install

FROM "${DOCKER_HUB_PROXY}debian:bullseye-slim" as python-build
    ENV DEBIAN_FRONTEND noninteractive
    RUN apt-get update; apt-get install -y --no-install-recommends \
        gcc \
        git \
        python3 \
        python3-dev \
        python3-pip \
        python3-setuptools \
        python3-venv \
        python3-wheel \
        libfuzzy-dev \
        libffi-dev \
        ca-certificates \
        curl \
        && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

    RUN mkdir /wheels

    WORKDIR /tmp

    RUN git clone --depth 1 https://github.com/CybOXProject/mixbox.git; \
        cd mixbox || exit; python3 setup.py bdist_wheel -d /wheels; \
        sed -i 's/-e //g' requirements.txt; pip3 wheel -r requirements.txt --no-cache-dir -w /wheels/

    # install python-maec
    RUN git clone --depth 1 https://github.com/MAECProject/python-maec.git; \
        cd python-maec || exit; python3 setup.py bdist_wheel -d /wheels

    # install python-cybox
    RUN git clone --depth 1 https://github.com/CybOXProject/python-cybox.git; \
        cd python-cybox || exit; python3 setup.py bdist_wheel -d /wheels; \
        sed -i 's/-e //g' requirements.txt; pip3 wheel -r requirements.txt --no-cache-dir -w /wheels/

    # install python stix
    RUN git clone --depth 1 https://github.com/STIXProject/python-stix.git; \
        cd python-stix || exit; python3 setup.py bdist_wheel -d /wheels; \
        sed -i 's/-e //g' requirements.txt; pip3 wheel -r requirements.txt --no-cache-dir -w /wheels/

    # install STIX2.0 library to support STIX 2.0 export:
    # Original Requirements has a bunch of non-required pacakges, force it to only grab wheels for deps from setup.py
    RUN git clone --depth 1 https://github.com/MISP/cti-python-stix2.git; \
        cd cti-python-stix2 || exit; python3 setup.py bdist_wheel -d /wheels; \
        echo "-e ." > requirements.txt; pip3 wheel -r requirements.txt --no-cache-dir -w /wheels/

    # Install the new build tool
    RUN pip3 install build

    # install PyMISP
    RUN git clone --depth 1 https://github.com/MISP/PyMISP.git; \
        cd PyMISP || exit; python3 -m build --wheel --outdir /wheels

    # install pydeep2 (drop-in replacement for pydeep)
    RUN git clone --depth 1 https://github.com/JakubOnderka/pydeep.git; \
        cd pydeep || exit; python3 setup.py bdist_wheel -d /wheels

    # Grab other modules we need
    RUN pip3 wheel --no-cache-dir -w /wheels/ plyara pyzmq redis python-magic lief>=0.13.1

    # Remove extra packages due to incompatible requirements.txt files
    WORKDIR /wheels
    RUN find . -name "Sphinx*" | tee /dev/stderr | grep -v "Sphinx-1.5.5" | xargs rm -f


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
        git \
        cron \
        openssl \
        gpg-agent gpg \
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

    # Download MISP using git in the /var/www/ directory.
    RUN if [ ! -z ${MISP_COMMIT} ]; then \
        git clone https://github.com/MISP/MISP.git /var/www/MISP && cd /var/www/MISP && git checkout ${MISP_COMMIT}; \
        else git clone --branch ${MISP_TAG} --depth 1 https://github.com/MISP/MISP.git /var/www/MISP; fi
    RUN cd /var/www/MISP; git submodule update --init --recursive .; cd /var/www/MISP/app; \
        # Remove some old and broken links that pollute the log files
        rm -rf /var/www/MISP/INSTALL/old

    # Python Modules
    COPY --from=python-build /wheels /wheels
    RUN pip3 install --no-cache-dir /wheels/*.whl && rm -rf /wheels

    # PHP: install prebuilt libraries, then install the app's PHP deps
    COPY --from=php-build /usr/lib/php/${PHP_VER}/ssdeep.so /usr/lib/php/${PHP_VER}/ssdeep.so
    COPY --from=php-build /usr/lib/php/${PHP_VER}/rdkafka.so /usr/lib/php/${PHP_VER}/rdkafka.so
    COPY --from=php-build /usr/lib/php/${PHP_VER}/brotli.so /usr/lib/php/${PHP_VER}/brotli.so
    COPY --from=php-build /usr/lib/php/${PHP_VER}/simdjson.so /usr/lib/php/${PHP_VER}/simdjson.so

    # Do an early chown to limit image size
    COPY --from=composer-build --chown=www-data:www-data /tmp/Vendor /var/www/MISP/app/Vendor
    COPY --from=composer-build --chown=www-data:www-data /tmp/Plugin /var/www/MISP/app/Plugin

    RUN for dir in /etc/php/*; do echo "extension=ssdeep.so" > "$dir/mods-available/ssdeep.ini"; done; phpenmod ssdeep
    RUN for dir in /etc/php/*; do echo "extension=rdkafka.so" > "$dir/mods-available/rdkafka.ini"; done; phpenmod rdkafka
    RUN for dir in /etc/php/*; do echo "extension=brotli.so" > "$dir/mods-available/brotli.ini"; done; phpenmod brotli
    RUN for dir in /etc/php/*; do echo "extension=simdjson.so" > "$dir/mods-available/simdjson.ini"; done; phpenmod simdjson
    RUN phpenmod redis

    # nginx
    RUN rm /etc/nginx/sites-enabled/*; mkdir /run/php /etc/nginx/certs
    COPY files/etc/nginx/misp /etc/nginx/sites-available/misp
    COPY files/etc/nginx/misp80 /etc/nginx/sites-available/misp80

    # Make a copy of the file and configuration stores, so we can sync from it
    RUN cp -R /var/www/MISP/app/files /var/www/MISP/app/files.dist; \
        cp -R /var/www/MISP/app/Config /var/www/MISP/app/Config.dist;

    # The spirit of the upstrem dockerization is to make:
    #   1) User and group aligned in terms of permissions
    #   2) Files executable and read only, because of some rogue scripts like 'cake'
    #   3) Directories writable, because sometimes MISP add new new files
    RUN find /var/www/MISP \( ! -user www-data -or ! -group www-data \) -exec chown www-data:www-data '{}' +; \
        find /var/www/MISP -not -perm 550 -type f -exec chmod 0550 '{}' +; \
        find /var/www/MISP -not -perm 770 -type d -exec chmod 0770 '{}' +;

    # Entrypoints
    COPY files/etc/supervisor/supervisor.conf /etc/supervisor/conf.d/10-supervisor.conf
    COPY files/etc/supervisor/workers.conf /etc/supervisor/conf.d/50-workers.conf
    COPY files/var/www/html/index.php /var/www/html/index.php
    COPY files/configure_misp.sh /
    COPY files/rest_client.sh /
    COPY files/entrypoint_fpm.sh /
    COPY files/entrypoint_nginx.sh /
    COPY files/entrypoint_cron.sh /
    COPY files/entrypoint.sh /
    ENTRYPOINT [ "/entrypoint.sh" ]

    # Change Workdirectory
    WORKDIR /var/www/MISP
