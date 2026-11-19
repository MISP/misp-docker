ARG DOCKER_HUB_PROXY=""

FROM "${DOCKER_HUB_PROXY}python:3.14-slim-trixie" AS python-build
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

WORKDIR /srv/misp-guard

RUN <<-EOF
    if [ -n "${GUARD_COMMIT}" ]; then
        git clone https://github.com/MISP/misp-guard.git . && git checkout "${GUARD_COMMIT}"
    else
        git clone --branch "${GUARD_TAG}" --depth 1 https://github.com/MISP/misp-guard.git .
    fi
EOF

WORKDIR /srv/misp-guard/src
RUN pip wheel -r requirements.txt --no-cache-dir -w /wheels/



FROM "${DOCKER_HUB_PROXY}python:3.14-slim-trixie"
ENV DEBIAN_FRONTEND=noninteractive

RUN <<-EOF
    apt-get update
    apt-get install -y --no-install-recommends \
        jq
    apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*
EOF

RUN --mount=type=bind,from=python-build,source=/wheels,target=/wheels \
    pip install --no-cache-dir /wheels/*.whl

# Installation is complete. Keep pip and its vendored dependencies out of the
# runtime, including the bundled wheel that could reinstall them via ensurepip.
RUN python -m pip uninstall --yes pip && \
    python -c 'import pathlib, shutil, sysconfig; shutil.rmtree(pathlib.Path(sysconfig.get_path("stdlib")) / "ensurepip")'

COPY --from=python-build /srv /srv
COPY files/ /

ENV GUARD_PORT=8888
EXPOSE 8888

HEALTHCHECK --interval=2m --timeout=5s --start-period=10s --retries=3 \
    CMD [ "bash", "-c", "</dev/tcp/127.0.0.1/${GUARD_PORT} || exit 1" ]

WORKDIR /srv/misp-guard/src
ENTRYPOINT [ "/entrypoint.sh" ]
