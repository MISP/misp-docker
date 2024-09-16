ARG DOCKER_HUB_PROXY=""

FROM "${DOCKER_HUB_PROXY}python:3.12-slim-bookworm" AS python-build
    ENV DEBIAN_FRONTEND noninteractive
    ARG MODULES_TAG
    ARG MODULES_COMMIT
    ARG LIBFAUP_COMMIT

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
        ninja-build \
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
    RUN sed -i "s/^python = .*/python = \"$(python -c 'import platform; print(platform.python_version())')\"/" pyproject.toml
    RUN poetry lock
    RUN poetry self add poetry-plugin-export
    RUN poetry export --with unstable --without-hashes -f requirements.txt -o requirements.txt
    RUN pip wheel -r requirements.txt --no-cache-dir -w /wheels/
    RUN poetry build --output /wheels/

    WORKDIR /srv/
    RUN rm -rf /srv/misp-modules

    RUN <<-EOF
        git clone --depth 1 https://github.com/stricaud/faup.git /srv/faup
        cd /srv/faup
        if [ ! -z ${LIBFAUP_COMMIT} ]; then
            git checkout ${LIBFAUP_COMMIT}
        fi
EOF

    WORKDIR /srv/faup/build
    RUN cmake -G "Ninja" ../
    RUN ninja
    RUN ninja install
    WORKDIR /srv/faup/src/lib/bindings/python
    RUN pip wheel --no-cache-dir --no-dependencies -w /wheels/ .

    WORKDIR /srv/
    RUN rm -rf /srv/faup


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
    COPY --from=python-build /usr/local/lib/libfaupl* /usr/local/lib/
    RUN ldconfig
    RUN pip install --no-cache-dir --use-deprecated=legacy-resolver /wheels/*.whl && rm -rf /wheels
    RUN pip uninstall -y pip

    # Since we compile faup ourselves and lua is not required anymore, we can load our own library 
    #   and skip the pre-compiled blob to improve compatibility with other architectures like ARM
    RUN sed -i s/LoadLibrary\(LOAD_LIB\)/LoadLibrary\(\"\\/usr\\/local\\/lib\\/libfaupl.so\"\)/ \
        /usr/local/lib/python3.12/site-packages/pyfaup/__init__.py

    # Disable (all) warnings raised when using 'future'
    RUN sed -i '/import sys/a import warnings\nwarnings.warn = lambda *args, **kwargs: None' \
        /usr/local/bin/misp-modules

    ENTRYPOINT [ "/usr/local/bin/misp-modules", "-l", "0.0.0.0"]
