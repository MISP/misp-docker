ARG DOCKER_HUB_PROXY=""
ARG MISP_UID=1001
ARG MISP_GID=1001


FROM "${DOCKER_HUB_PROXY}python:3.12-slim-trixie" AS python-build
ENV DEBIAN_FRONTEND=noninteractive
ARG MODULES_TAG
ARG MODULES_COMMIT
ARG MODULES_FLAVOR

# Uncomment when building in corporate environments
# COPY ./cert.pem /usr/local/share/ca-certificates/rootca.pem
# COPY ./cert.pem /usr/lib/ssl/cert.pem

RUN <<-EOF
        apt-get update
        if [ "${MODULES_FLAVOR}" = "slim" ]; then
            apt-get install -y --no-install-recommends \
                ca-certificates \
                git
        else
            apt-get install -y --no-install-recommends \
                ca-certificates \
                git \
                build-essential \
                libpoppler-cpp-dev
        fi
        apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*
EOF

RUN mkdir /wheels

RUN <<-EOF
        if [ ! -z ${MODULES_COMMIT} ]; then
            git clone https://github.com/MISP/misp-modules.git /srv/misp-modules && cd /srv/misp-modules && git checkout ${MODULES_COMMIT}
        else
            git clone --branch ${MODULES_TAG} --depth 1 https://github.com/MISP/misp-modules.git /srv/misp-modules
        fi
EOF

WORKDIR /srv/misp-modules
RUN pip install poetry
RUN sed -i "s/^requires-python = .*/requires-python = \"$(python -c 'import platform; print(platform.python_version())')\"/" pyproject.toml
RUN poetry lock
RUN poetry self add poetry-plugin-export
RUN <<-EOF
        if [ "${MODULES_FLAVOR}" = "slim" ]; then
            poetry export --without-hashes -f requirements.txt -o requirements.txt
        else
            poetry export -E all --without-hashes -f requirements.txt -o requirements.txt
        fi
EOF
RUN pip wheel -r requirements.txt --no-cache-dir -w /wheels/
RUN poetry build --output /wheels/

WORKDIR /srv/
RUN rm -rf /srv/misp-modules


FROM "${DOCKER_HUB_PROXY}python:3.12-slim-trixie"
ENV DEBIAN_FRONTEND=noninteractive
ARG MODULES_FLAVOR
ARG MISP_UID
ARG MISP_GID

RUN <<-EOF
        apt-get update
        if [ "${MODULES_FLAVOR}" = "slim" ]; then
            :
        else
            apt-get install -y --no-install-recommends \
                libgl1 \
                libpoppler-cpp2 \
                tesseract-ocr \
                libzbar0
        fi
        apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*
EOF

RUN groupadd -g "${MISP_GID}" misp && \
    useradd  -u "${MISP_UID}" -g "${MISP_GID}" -m -d /home/misp -s /usr/sbin/nologin misp

COPY --from=python-build /wheels /wheels
RUN pip install --no-cache-dir /wheels/*.whl && rm -rf /wheels
RUN bash -c 'mkdir -p /custom/{action_mod,expansion,export_mod,import_mod} && chown -R misp:misp /custom'

USER misp

ENTRYPOINT [ "/usr/local/bin/misp-modules", "-l", "0.0.0.0", "-c", "/custom/"]
