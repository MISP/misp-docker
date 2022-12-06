ARG DOCKER_HUB_PROXY=""

FROM "${DOCKER_HUB_PROXY}composer:2.1.14" as composer-build
    ARG MISP_TAG
    WORKDIR /tmp
    ADD https://raw.githubusercontent.com/MISP/MISP/${MISP_TAG}/app/composer.json /tmp
    RUN composer install --ignore-platform-reqs && \
     composer require jakub-onderka/openid-connect-php:1.0.0-rc1 --ignore-platform-reqs && \
     composer require --with-all-dependencies supervisorphp/supervisor:^4.0 \
      guzzlehttp/guzzle php-http/message lstrojny/fxmlrpc --ignore-platform-reqs

FROM "${DOCKER_HUB_PROXY}debian:bullseye-slim" as php-build
    RUN apt-get update; apt-get install -y --no-install-recommends \
        gcc \
        make \
        libfuzzy-dev \
        ca-certificates \
        php \
        php-dev \
        php-pear \
        librdkafka-dev \
        git \
        && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*
        
        RUN pecl channel-update pecl.php.net
        RUN cp "/usr/lib/$(gcc -dumpmachine)"/libfuzzy.* /usr/lib; pecl install ssdeep && pecl install rdkafka
        RUN git clone --recursive --depth=1 https://github.com/kjdev/php-ext-brotli.git && cd php-ext-brotli && phpize && ./configure && make && make install
        

FROM "${DOCKER_HUB_PROXY}debian:bullseye-slim" as python-build
    RUN apt-get update; apt-get install -y --no-install-recommends \
        gcc \
        git \
        python3 \
        python3-dev \
        python3-pip \
        python3-setuptools \
        python3-wheel \
        libfuzzy-dev \
        libffi-dev \
        ca-certificates \
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

    # install PyMISP
    RUN git clone --depth 1 https://github.com/MISP/PyMISP.git; \
        cd PyMISP || exit; python3 setup.py bdist_wheel -d /wheels

    # install pydeep
    RUN git clone --depth 1 https://github.com/coolacid/pydeep.git; \
        cd pydeep || exit; python3 setup.py bdist_wheel -d /wheels

    # Grab other modules we need
    RUN pip3 wheel --no-cache-dir -w /wheels/ plyara pyzmq redis python-magic lief

    # Remove extra packages due to incompatible requirements.txt files
    WORKDIR /wheels
    RUN find . -name "Sphinx*" | tee /dev/stderr | grep -v "Sphinx-1.5.5" | xargs rm -f


FROM "${DOCKER_HUB_PROXY}debian:bullseye-slim"
ENV DEBIAN_FRONTEND noninteractive
ARG MISP_TAG
ARG MISP_COMMIT
ARG PHP_VER

# OS Packages
    RUN apt-get update; apt-get install -y --no-install-recommends \
        # Requirements:
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
        # Unsure we need these
        zip unzip \
        # Require for advanced an unattended configuration
        curl jq \
        && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# MISP code
    # Download MISP using git in the /var/www/ directory.
    RUN git clone --branch ${MISP_TAG} --depth 1 https://github.com/MISP/MISP.git /var/www/MISP
    RUN if [ ! -z ${MISP_COMMIT} ]; then cd /var/www/MISP && git checkout ${MISP_COMMIT}; fi; \
        # We build the MISP modules outside, so we don't need to grab those submodules
        cd /var/www/MISP/app || exit; git submodule update --init --recursive .; \
        # Remove some old and broken links that pollute the log files
        rm -rf /var/www/MISP/INSTALL/old

# Python Modules
    COPY --from=python-build /wheels /wheels
    RUN pip3 install --no-cache-dir /wheels/*.whl && rm -rf /wheels

# PHP
    # Install ssdeep prebuild, latest composer, then install the app's PHP deps
    COPY --from=php-build /usr/lib/php/${PHP_VER}/ssdeep.so /usr/lib/php/${PHP_VER}/ssdeep.so
    COPY --from=php-build /usr/lib/php/${PHP_VER}/rdkafka.so /usr/lib/php/${PHP_VER}/rdkafka.so
    COPY --from=php-build /usr/lib/php/${PHP_VER}/brotli.so /usr/lib/php/${PHP_VER}/brotli.so

    COPY --from=composer-build /tmp/Vendor /var/www/MISP/app/Vendor
    COPY --from=composer-build /tmp/Plugin /var/www/MISP/app/Plugin
    
    RUN for dir in /etc/php/*; do echo "extension=rdkafka.so" > "$dir/mods-available/rdkafka.ini"; done; phpenmod rdkafka
    RUN for dir in /etc/php/*; do echo "extension=brotli.so" > "$dir/mods-available/brotli.ini"; done; phpenmod brotli

    RUN for dir in /etc/php/*; do echo "extension=ssdeep.so" > "$dir/mods-available/ssdeep.ini"; done \
            ;phpenmod redis \
    # Enable ssdeep we build earlier
        ;phpenmod ssdeep

# nginx
    RUN rm /etc/nginx/sites-enabled/*; mkdir /run/php /etc/nginx/certs
    COPY files/etc/nginx/misp /etc/nginx/sites-available/misp
    COPY files/etc/nginx/misp-secure /etc/nginx/sites-available/misp-secure
    COPY files/etc/nginx/misp80 /etc/nginx/sites-available/misp80
    COPY files/etc/nginx/misp80-noredir /etc/nginx/sites-available/misp80-noredir

# Make a copy of the file store, so we can sync from it
    RUN cp -R /var/www/MISP/app/files /var/www/MISP/app/files.dist

# Make a copy of the configurations, so we can sync from it
    RUN cp -R /var/www/MISP/app/Config /var/www/MISP/app/Config.dist

# Entrypoints
    COPY files/etc/supervisor/supervisor.conf /etc/supervisor/conf.d/10-supervisor.conf
    COPY files/etc/supervisor/workers.conf /etc/supervisor/conf.d/50-workers.conf
    COPY files/entrypoint_internal.sh /
    COPY files/entrypoint_fpm.sh /
    COPY files/entrypoint_nginx.sh /
    COPY files/entrypoint_cron.sh /
    COPY files/entrypoint.sh /
    ENTRYPOINT [ "/entrypoint.sh" ]

# Change Workdirectory
    WORKDIR /var/www/MISP
