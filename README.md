# TAU's MISP Docker images

[![Build Status](https://img.shields.io/github/workflow/status/ostefano/docker-misp/Build%20the%20Docker%20images%20and%20push%20them%20to%20Docker%20Hub)](https://hub.docker.com/repository/docker/ostefano/misp-docker)
[![Gitter chat](https://badges.gitter.im/gitterHQ/gitter.png)](https://gitter.im/MISP/Docker)

A production ready Dockered MISP based on CoolAcid's MISP Docker image (https://github.com/coolacid/docker-misp).

Like CoolAcid's MISP docker image, this is based on some of the work from the DSCO docker build, nearly all of the details have been rewritten.

-   Components are split out where possible, currently this is only the MISP modules
-   Over writable configuration files
-   Allows volumes for file store
-   Cron job runs updates, pushes, and pulls - Logs go to docker logs
-   Docker-Compose uses off the shelf images for Redis and MySQL
-   Images directly from docker hub, no build required
-   Slimmed down images by using build stages and slim parent image, removes unnecessary files from images

Additionally, this fork features the following improvements:

-   ARM (Apple M1) support
-   Fix and improve support for cron jobs
-   Fix Supervisor handling of entrypoints
-   Make schema update repeatable and completely offline
-   Fix missing MISP modules dependencies
-   New Background Job system, see https://github.com/MISP/MISP/blob/2.4/docs/background-jobs-migration-guide.md
-   Automatic configuration of MISP modules (see `entrypoint_internal.sh`)
-   Automatic configuration of sync servers (see `entrypoint_internal.sh`)
-   Automatic configuration of organizations (see `entrypoint_internal.sh`)
-   Autoamtic configuration of authentication keys (see `entrypoint_internal.sh`)

As a result, this image is not for everybody and does not (and will not) fit every use case.
Nevertheless the underlying spirit of this fork is to allow "repeatable deployments", and all pull requests in this direction will be merged.

## Versioning

GitHub builds the images automatically and pushes them to [Docker hub](https://hub.docker.com/r/ostefano/misp-docker). We do not use tags and versioning works as follows:

-   MISP (and modules) version specified inside the `template.env` file
-   Docker images are tagged based on the commit hash
-   Core and modules are tagged as core-commit-sha1[0:7] and modules-commit-sha1[0:7] respectively
-   The latest images have additional tags core-latest and modules-latest

## Getting Started

-   Copy the `template.env` to `.env` and fill the missing configuration variables

### Development/Test

-   `docker-compose up`

-   Login to `https://localhost`
    -   User: `admin@admin.test`
    -   Password: `admin`

-   Profit

### Using the image for development

Pull the entire repository, you can build the images using `docker-compose build`

Once you have the docker container up you can access the container by running `docker-compose exec misp /bin/bash`.
This will provide you with a root shell. You can use `apt update` and then install any tools you wish to use.
Finally, copy any changes you make outside of the container for commiting to your branch. 
`git diff -- [dir with changes]` could be used to reduce the number of changes in a patch file, however, becareful when using the `git diff` command.

### Updating

Updating the images should be as simple as `docker-compose pull` which, unless changed in the `docker-compose.yml` file will pull the latest built images.

### Production
-   It is recommended to specify which build you want to be running, and modify that version number when you would like to upgrade

-   Use docker-compose, or some other config management tool

-   Directory volume mount SSL Certs `./ssl`: `/etc/ssl/certs`
    -   Certificate File: `cert.pem`
    -   Certificate Key File: `key.pem`
    -   CA File for Cert Authentication (optional) `ca.pem`

-   Directory volume mount and create configs: `/var/www/MISP/app/Config/`

-   Additional directory volume mounts:
    -   `/var/www/MISP/app/files`
    -   `/var/www/MISP/.gnupg`

### Building

If you are interested in building the project from scratch - `git clone` or download the entire repo and run `docker-compose build` 

## Image file sizes

-   Core server(Saved: 2.5GB)
    -   Original Image: 3.17GB
    -   First attempt: 2.24GB
    -   Remove chown: 1.56GB
    -   PreBuild python modules, and only pull submodules we need: 800MB
    -   PreBuild PHP modules: 664MB

-   Modules (Saved: 640MB)
    -   Original: 1.36GB
    -   Pre-build modules: 750MB

### Configuration

The `docker-compose.yml` file further allows the following configuration settings:

```
"MYSQL_HOST=db"
"MYSQL_USER=misp"
"MYSQL_PASSWORD=example"    # NOTE: This should be AlphaNum with no Special Chars. Otherwise, edit config files after first run. 
"MYSQL_DATABASE=misp"
"NOREDIR=true"              # Do not redirect port 80
"DISIPV6=true"              # Disable IPV6 in nginx
"CERTAUTH=optional"         # Can be set to optional or on - Step 2 of https://github.com/MISP/MISP/tree/2.4/app/Plugin/CertAuth is still required
"SECURESSL=true"            # Enable higher security SSL in nginx
"MISP_MODULES_FQDN=http://misp-modules" # Set the MISP Modules FQDN, used for Enrichment_services_url/Import_services_url/Export_services_url
"WORKERS=1"                 # Legacy variable controlling the number of parallel workers (use variables below instead)
"NUM_WORKERS_DEFAULT=5"     # To set the number of default workers
"NUM_WORKERS_PRIO=5"        # To set the number of prio workers
"NUM_WORKERS_EMAIL=5"       # To set the number of email workers
"NUM_WORKERS_UPDATE=1"      # To set the number of update workers
"NUM_WORKERS_CACHE=5"       # To set the number of cache workers
```
