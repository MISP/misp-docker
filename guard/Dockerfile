ARG DOCKER_HUB_PROXY=""

FROM "${DOCKER_HUB_PROXY}python:3.12-slim-trixie" AS python-build
    ENV DEBIAN_FRONTEND=noninteractive
    ARG GUARD_TAG
    ARG GUARD_COMMIT

    RUN <<-EOF
        apt-get update
        apt-get install -y --no-install-recommends \
            ca-certificates \
            git
        apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*
EOF

    RUN mkdir /wheels

    RUN <<-EOF
        if [ ! -z ${GUARD_COMMIT} ]; then
            git clone https://github.com/MISP/misp-guard.git /srv/misp-guard && cd /srv/misp-guard && git checkout ${GUARD_COMMIT}
        else
            git clone --branch ${GUARD_TAG} --depth 1 https://github.com/MISP/misp-guard.git /srv/misp-guard
        fi
EOF

    WORKDIR /srv/misp-guard/src
    RUN pip wheel -r requirements.txt --no-cache-dir -w /wheels/



FROM "${DOCKER_HUB_PROXY}python:3.12-slim-trixie"
    ENV DEBIAN_FRONTEND=noninteractive
    ARG GUARD_UID=1001
    ARG GUARD_GID=1001

    RUN <<-EOF
        apt-get update
        apt-get install -y --no-install-recommends \
            jq
        apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*
EOF

    COPY --from=python-build /wheels /wheels
    RUN pip install --no-cache-dir /wheels/*.whl && rm -rf /wheels

    COPY --from=python-build /srv /srv
    COPY files/ /

    # Non-root by default, and group-0-writable so this also works when
    # OpenShift runs the container under its own arbitrary UID (always
    # paired with primary group 0, regardless of this image's USER).
    RUN groupadd -g "${GUARD_GID}" guard && \
        useradd -u "${GUARD_UID}" -g "${GUARD_GID}" -m -d /home/guard -s /usr/sbin/nologin guard && \
        usermod -aG 0 guard && \
        mkdir -p /home/guard/.mitmproxy /misp_guard_ca && \
        chown -R guard:0 /srv /home/guard /misp_guard_ca && \
        chmod -R g=u /srv /home/guard /misp_guard_ca && \
        find /srv /home/guard /misp_guard_ca -type d -exec chmod g+s {} +

    ENV HOME=/home/guard
    USER guard
    WORKDIR /srv/misp-guard/src
    ENTRYPOINT [ "/entrypoint.sh" ]
