FROM python:3.12-slim-bookworm

RUN apt-get update
RUN apt-get update && \
    apt-get install -y --no-install-recommends git && \
    rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/MISP/misp-guard.git /srv/misp-guard/
WORKDIR /srv/misp-guard/src
RUN pip install -r requirements.txt

# replace with volume
# COPY ./config.json /srv/misp-guard/src/

EXPOSE 8888

CMD ["mitmdump", "-s", "mispguard.py", "-p", "8888", "--set", "config=config.json"]