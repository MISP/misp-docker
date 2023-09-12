ARG DOCKER_HUB_PROXY=""

FROM "${DOCKER_HUB_PROXY}python:3.11-slim-bullseye" as python-build
    ENV DEBIAN_FRONTEND noninteractive
    ARG MODULES_TAG
    ARG MODULES_COMMIT
    ARG LIBFAUP_COMMIT
    RUN apt-get update && apt-get install -y --no-install-recommends \
        cmake \
        git \
        python3-dev \
        python3-pip \
        python3-wheel \
        build-essential \
        pkg-config \
        libpoppler-cpp-dev \
        libfuzzy-dev \
        libssl-dev \
        ninja-build \
        && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*
    
    RUN mkdir /wheels
    WORKDIR /srv

    RUN <<-EOF
            if [ ! -z ${MODULES_COMMIT} ]; then
                git clone https://github.com/MISP/misp-modules.git /srv/misp-modules && cd /srv/misp-modules && git checkout ${MODULES_COMMIT}
            else
                git clone --branch ${MODULES_TAG} --depth 1 https://github.com/MISP/misp-modules.git /srv/misp-modules
            fi

            cd /srv/misp-modules
            echo "pyeti" >> REQUIREMENTS
            echo "greynoise" >> REQUIREMENTS
            echo "git+https://github.com/abenassi/Google-Search-API" >> REQUIREMENTS
            sed -i 's|.*apiosintDS.*|apiosintDS==2.0.1|g' REQUIREMENTS
            # let apiosintDS decide since misp-modules doesn't actually use this package anyway
            sed -i '/validators.*/d' REQUIREMENTS
            sed -i 's/-e //g' REQUIREMENTS
            pip3 wheel -r REQUIREMENTS --no-cache-dir -w /wheels/
            rm -rf /srv/misp-modules
EOF

    RUN <<-EOF
        git clone --depth 1 https://github.com/stricaud/faup.git /srv/faup
        cd /srv/faup
        git checkout ${LIBFAUP_COMMIT}
        cd /srv/faup/build
        cmake -G "Ninja" ../
        ninja
        ninja install
        cd /srv/faup/src/lib/bindings/python
        pip3 wheel --no-cache-dir --no-dependencies -w /wheels/ .
        rm -rf /srv/faup
EOF

FROM "${DOCKER_HUB_PROXY}python:3.11-slim-bullseye"
    ENV DEBIAN_FRONTEND noninteractive
    RUN apt-get update && apt-get install -y --no-install-recommends \
        libglib2.0-0 \
        libzbar0 \
        libxrender1 \
        libxext6 \
        libpoppler-cpp0v5 \
        libgl1 \
        && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*
    
    COPY --from=python-build /wheels /wheels
    COPY --from=python-build /usr/local/lib/libfaupl* /usr/local/lib/
    RUN pip3 install --no-cache-dir --use-deprecated=legacy-resolver /wheels/*.whl; ldconfig && rm -rf /wheels
    
    # Since we compile faup ourselves and lua is not required anymore, we can load our own library 
    #   and skip the pre-compiled blob to improve compatibility with other architectures like ARM
    RUN sed -i s/LoadLibrary\(LOAD_LIB\)/LoadLibrary\(\"\\/usr\\/local\\/lib\\/libfaupl.so\"\)/ \
        /usr/local/lib/python3.11/site-packages/pyfaup/__init__.py

    # Disable (all) warnings raised when using 'future'
    RUN sed -i '/import sys/a import warnings\nwarnings.warn = lambda *args, **kwargs: None' \
        /usr/local/bin/misp-modules

    ENTRYPOINT [ "/usr/local/bin/misp-modules", "-l", "0.0.0.0"]
