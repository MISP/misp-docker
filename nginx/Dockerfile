# --- sources stage
FROM ghcr.io/nginx/nginx-unprivileged:1.31.2-trixie AS sources

ARG CORE_TAG
ARG CORE_COMMIT

# environment
ENV DEBIAN_FRONTEND=noninteractive

# ensure directory exists with permissions for nginx user
WORKDIR /var/www

# install git
USER root
RUN apt-get update && \
    apt-get install -y --no-install-recommends git && \
    apt-get autoremove -y && \
    apt-get clean -y && \
    rm -rf /var/lib/apt/lists/*
USER nginx

# clone source code into /var/www directory
RUN <<-EOF
    if [ ! -z "${CORE_COMMIT}" ]; then
        git clone https://github.com/MISP/MISP.git /var/www/MISP && cd /var/www/MISP && git checkout "${CORE_COMMIT}"
    else
        git clone --branch "${CORE_TAG}" --depth 1 https://github.com/MISP/MISP.git /var/www/MISP
    fi

    cd /var/www/MISP || exit; git submodule update --init --recursive ./app/webroot
EOF

# --- final stage
FROM ghcr.io/nginx/nginx-unprivileged:1.31.2-trixie

# environment
ENV NGINX_INTERNAL_HTTP_PORT=8080
ENV NGINX_INTERNAL_HTTPS_PORT=8443
ENV NGINX_INTERNAL_STATUS_PORT=8081
ENV NGINX_INCLUDE_DIR=/etc/nginx/conf.d/include

# remove default page
RUN rm -rf /etc/nginx/conf.d/*

# copy entrypoints
COPY files/00-misp.envsh /docker-entrypoint.d/00-misp.envsh
COPY files/01-listen.sh /docker-entrypoint.d/01-listen.sh
COPY files/02-real-ip.sh /docker-entrypoint.d/02-real-ip.sh
COPY files/03-conditional-headers.sh /docker-entrypoint.d/03-conditional-headers.sh
COPY files/04-ssl.sh /docker-entrypoint.d/04-ssl.sh
COPY files/05-gpg-key.sh /docker-entrypoint.d/05-gpg-key.sh

# copy nginx configs
COPY --chown=nginx:nginx files/misp.conf /etc/nginx/templates/misp.conf.template
COPY --chown=nginx:nginx files/status.conf /etc/nginx/templates/status.conf.template

# copy source code
COPY --from=sources --chown=nginx:nginx /var/www/MISP/app/webroot /var/www/MISP/app/webroot

# expose port
EXPOSE ${NGINX_INTERNAL_HTTP_PORT} ${NGINX_INTERNAL_HTTPS_PORT}

# health check via status page
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD bash -c 'echo > /dev/tcp/127.0.0.1/${NGINX_INTERNAL_STATUS_PORT}' || exit 1
