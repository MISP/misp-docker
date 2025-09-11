FROM python:3.12-slim-bookworm

RUN apt-get update && \
    apt-get install -y --no-install-recommends git jq && \
    rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/MISP/misp-guard.git /srv/misp-guard/
WORKDIR /srv/misp-guard/src
RUN pip install -r requirements.txt

# resolve ip of misp-core and inject into config.json inside container
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh