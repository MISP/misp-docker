ARG DOCKER_HUB_PROXY=""
ARG MISP_UID=1001
ARG MISP_GID=1001


FROM "${DOCKER_HUB_PROXY}python:3.14-slim-trixie" AS python-build
ENV DEBIAN_FRONTEND=noninteractive
ARG MODULES_TAG
ARG MODULES_COMMIT

# Uncomment when building in corporate environments
# COPY ./cert.pem /usr/local/share/ca-certificates/rootca.pem
# COPY ./cert.pem /usr/lib/ssl/cert.pem

RUN <<-EOF
    apt-get update
    apt-get install -y --no-install-recommends \
        ca-certificates \
        git \
        build-essential \
        libfuzzy-dev \
        libpoppler-cpp-dev
    apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*
EOF

RUN mkdir /wheels

WORKDIR /srv/misp-modules

RUN <<-EOF
    if [ ! -z "${MODULES_COMMIT}" ]; then
        git clone https://github.com/MISP/misp-modules.git . && git checkout "${MODULES_COMMIT}"
    else
        git clone --branch "${MODULES_TAG}" --depth 1 https://github.com/MISP/misp-modules.git .
    fi
EOF

RUN pip install --no-cache-dir poetry poetry-plugin-bundle poetry-plugin-export && \
    poetry export -E all --without-hashes -f requirements.txt -o requirements.txt && \
    pip wheel -r requirements.txt --no-cache-dir -w /wheels/ && \
    poetry build --output /wheels/

WORKDIR /srv/
RUN rm -rf /srv/misp-modules


FROM "${DOCKER_HUB_PROXY}python:3.14-slim-trixie"
ENV DEBIAN_FRONTEND=noninteractive
ARG MISP_UID
ARG MISP_GID

RUN <<-EOF
    apt-get update
    apt-get install -y --no-install-recommends \
        libgl1 \
        libfuzzy2 \
        libpoppler-cpp2 \
        libzbar0 \
        tesseract-ocr
    apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*
EOF

RUN groupadd -g "${MISP_GID}" misp && \
    useradd -l -u "${MISP_UID}" -g "${MISP_GID}" -m -d /home/misp -s /usr/sbin/nologin misp

RUN --mount=type=bind,from=python-build,source=/wheels,target=/wheels \
    pip install --no-cache-dir /wheels/*.whl

# Installation is complete. Keep pip and its vendored dependencies out of the
# runtime, including the bundled wheel that could reinstall them via ensurepip.
RUN python -m pip uninstall --yes pip && \
    python -c 'import pathlib, shutil, sysconfig; shutil.rmtree(pathlib.Path(sysconfig.get_path("stdlib")) / "ensurepip")'

RUN bash -c 'mkdir -p /custom/{action_mod,expansion,export_mod,import_mod} && chown -R misp:misp /custom'

USER ${MISP_UID}

EXPOSE 6666

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD [ "bash", "-c", "</dev/tcp/127.0.0.1/6666 || exit 1" ]

ENTRYPOINT [ "/usr/local/bin/misp-modules", "-l", "0.0.0.0", "-c", "/custom/"]
