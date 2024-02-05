# MISP Docker images

[![Build Status](https://img.shields.io/github/actions/workflow/status/MISP/misp-docker/release-latest.yml)](https://github.com/orgs/MISP/packages)
[![Gitter chat](https://badges.gitter.im/gitterHQ/gitter.png)](https://gitter.im/MISP/Docker)

A production ready Docker MISP image (formerly hosted at https://github.com/ostefano/docker-misp, now deprecated) loosely based on CoolAcid and DSCO builds, with nearly all logic rewritten and verified for correctness and portability.

Notable features:
-   MISP and MISP modules are split into two different Docker images, `misp-core` and `misp-modules`
-   Docker images are pushed regularly, no build required
-   Lightweigth Docker images by using multiple build stages and a slim parent image
-   Rely on off the shelf Docker images for Exim4, Redis, and MariaDB
-   Cron jobs run updates, pushes, and pulls
-   Fix supervisord process control (processes are correctly terminated upon reload)
-   Fix schema update by making it completely offline (no user interaction required)
-   Fix enforcement of permissions
-   Fix MISP modules loading of faup library
-   Fix MISP modules loading of gl library
-   Add support for new background job [system](https://github.com/MISP/MISP/blob/2.4/docs/background-jobs-migration-guide.md)
-   Add support for building specific MISP and MISP-modules commits
-   Add automatic configuration of syncservers (see `configure_misp.sh`)
-   Add automatic configuration of authentication keys (see `configure_misp.sh`)
-   Add direct push of docker images to GitHub Packages
-   Consolidated `docker-compose.yml` file
-   Workardound VirtioFS bug when running Docker Desktop for Mac
-   ... and many others

The underlying spirit of this project is to allow "repeatable deployments", and all pull requests in this direction will be merged post-haste.

## Getting Started

-   Copy the `template.env` to `.env` 
-   Customize `.env` based on your needs (optional step)

### Run

-   `docker-compose pull` if you want to use pre-built images or `docker-compose build` if you want to build your own (see the `Troubleshooting` section in case of errors)
-   `docker-compose up`
-   Login to `https://localhost`
    -   User: `admin@admin.test`
    -   Password: `admin`

Keeping the image up-to-date with upstream should be as simple as running `docker-compose pull`.

### Configuration

The `docker-compose.yml` file allows further configuration settings:

```
"MYSQL_HOST=db"
"MYSQL_USER=misp"
"MYSQL_PASSWORD=example"    # NOTE: This should be AlphaNum with no Special Chars. Otherwise, edit config files after first run.
"MYSQL_DATABASE=misp"
"MISP_MODULES_FQDN=http://misp-modules" # Set the MISP Modules FQDN, used for Enrichment_services_url/Import_services_url/Export_services_url
"WORKERS=1"                 # Legacy variable controlling the number of parallel workers (use variables below instead)
"NUM_WORKERS_DEFAULT=5"     # To set the number of default workers
"NUM_WORKERS_PRIO=5"        # To set the number of prio workers
"NUM_WORKERS_EMAIL=5"       # To set the number of email workers
"NUM_WORKERS_UPDATE=1"      # To set the number of update workers
"NUM_WORKERS_CACHE=5"       # To set the number of cache workers
```

New options are added on a regular basis.

### Production

-   It is recommended to specify the build you want run by editing `docker-compose.yml` (see here for the list of available tags https://github.com/orgs/MISP/packages)
-   Directory volume mount SSL Certs `./ssl`: `/etc/ssl/certs`
    -   Certificate File: `cert.pem`
    -   Certificate Key File: `key.pem`
    -   CA File for Cert Authentication (optional) `ca.pem`
-   Additional directory volume mounts:
    -   `./configs`: `/var/www/MISP/app/Config/`
    -   `./logs`: `/var/www/MISP/app/tmp/logs/`
    -   `./files`: `/var/www/MISP/app/files/`
    -   `./gnupg`: `/var/www/MISP/.gnupg/`
-   If you need to automatically run additional steps each time the container starts, create a new file `files/customize_misp.sh`, and replace the variable `${CUSTOM_PATH}` inside `docker-compose.yml` with its parent path.

## Installing custom root CA certificates

Custom root CA certificates can be mounted under `/usr/local/share/ca-certificates` and will be installed during the `misp-core` container start.

**Note:** It is important to have the .crt extension on the file, otherwise it will not be processed.

```yaml
  misp-core:
    # ...
    volumes:
      - "./configs/:/var/www/MISP/app/Config/"
      - "./logs/:/var/www/MISP/app/tmp/logs/"
      - "./files/:/var/www/MISP/app/files/"
      - "./ssl/:/etc/nginx/certs/"
      - "./gnupg/:/var/www/MISP/.gnupg/"
      # customize by replacing ${CUSTOM_PATH} with a path containing 'files/customize_misp.sh'
      # - "${CUSTOM_PATH}/:/custom/"
      # mount custom ca root certificates
      - "./rootca.pem:/usr/local/share/ca-certificates/rootca.crt"
```

## Troubleshooting

-   Make sure you run a fairly recent version of Docker and Docker Compose (if in doubt, update following the steps outlined in https://docs.docker.com/engine/install/ubuntu/)
-   Some Linux distributions provide a recent version of Docker but a legacy version of Docker Compose, so you can try running `docker compose` instead of `docker-compose`
-   Make sure you are not running an old image or container; when in doubt run `docker system prune --volumes` and clone this repository into an empty directory

## Versioning

A GitHub Action builds both `misp-core` and `misp-modules` images automatically and pushes them to the [GitHub Package registry](https://github.com/orgs/MISP/packages). We do not use tags inside the repository; instead we tag images as they are pushed to the registry. For each build, `misp-core` and `misp-modules` images are tagged as follows:
-   `misp-core:${commit-sha1}[0:7]` and `misp-modules:${commit-sha1}[0:7]` where `${commit-sha1}` is the commit hash triggering the build
-   `misp-core:latest` and `misp-modules:latest` in order to track the latest builds available 
-   `misp-core:${CORE_TAG}` and `misp-modules:${MODULES_TAG}` reflecting the underlying version of MISP and MISP modules (as specified inside the `template.env` file at build time)
