ARG DOCKER_HUB_PROXY=""

FROM "${DOCKER_HUB_PROXY}python:3.12-slim-bookworm" AS python-build
    ENV DEBIAN_FRONTEND noninteractive
    ARG MODULES_TAG
    ARG MODULES_COMMIT
    ARG MODULES_INSTALL_FLAG

    # Uncomment when building in corporate environments
    # COPY ./cert.pem /usr/local/share/ca-certificates/rootca.pem
    # COPY ./cert.pem /usr/lib/ssl/cert.pem

    RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        cmake \
        git \
        build-essential \
        libpoppler-cpp-dev \
        libfuzzy-dev \
        libffi-dev \
        libxml2-dev \
        libxslt-dev  \
        libssl-dev \
        && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

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
    RUN poetry export ${MODULES_INSTALL_FLAG} --without-hashes -f requirements.txt -o requirements.txt
    RUN pip wheel -r requirements.txt --no-cache-dir -w /wheels/
    RUN poetry build --output /wheels/

    WORKDIR /srv/
    RUN rm -rf /srv/misp-modules


FROM "${DOCKER_HUB_PROXY}python:3.12-slim-bookworm"
    ENV DEBIAN_FRONTEND noninteractive

    RUN apt-get update && apt-get install -y --no-install-recommends \
        libglib2.0-0 \
        libpoppler-cpp0v5 \
        libgl1 \
        libfuzzy2 \
        libffi8 \
        libxext6 \
        libxml2 \
        libxslt1.1  \
        libzbar0 \
        && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

    COPY --from=python-build /wheels /wheels
    RUN pip install --no-cache-dir /wheels/*.whl && rm -rf /wheels
    RUN pip uninstall -y pip

    # Disable (all) warnings raised when using 'future'
    RUN sed -i '/import sys/a import warnings\nwarnings.warn = lambda *args, **kwargs: None' \
        /usr/local/bin/misp-modules

    ENTRYPOINT [ "/usr/local/bin/misp-modules", "-l", "0.0.0.0"]
