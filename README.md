# MISP Docker images

[![Build Status](https://img.shields.io/github/actions/workflow/status/MISP/misp-docker/release-latest.yml)](https://github.com/orgs/MISP/packages)
[![Gitter chat](https://badges.gitter.im/gitterHQ/gitter.png)](https://gitter.im/MISP/Docker)

A production ready Docker MISP image (formerly hosted at <https://github.com/ostefano/docker-misp>, now deprecated) loosely based on CoolAcid and DSCO builds, with nearly all logic rewritten and verified for correctness and portability.

Notable features:

- MISP and MISP modules are split into two different Docker images, `misp-core` and `misp-modules`
- Optional [MISP-Guard](https://github.com/MISP/misp-guard) container to filter traffic and enforce sharing policies via mitmproxy.
- Docker images are pushed regularly, no build required
- Lightweight Docker images by using multiple build stages and a slim parent image
- Rely on off the shelf Docker images for Exim4, Redis, and MariaDB
- Scheduled tasks run updates, pushes, and pulls
- Fix supervisord process control (processes are correctly terminated upon reload)
- Fix schema update by making it completely offline (no user interaction required)
- Fix enforcement of permissions
- Fix MISP modules loading of faup library
- Fix MISP modules loading of gl library
- Authentication using LDAP or OIDC
- Add support for new background job [system](https://github.com/MISP/MISP/blob/2.4/docs/background-jobs-migration-guide.md)
- Add support for building specific MISP and MISP-modules commits
- Add automatic configuration of syncservers (see `configure_misp.sh`)
- Add automatic configuration of authentication keys (see `configure_misp.sh`)
- Add direct push of docker images to GitHub Packages
- Consolidated `docker-compose.yml` file
- Workaround VirtioFS bug when running Docker Desktop for Mac
- ... and many others

The underlying spirit of this project is to allow "repeatable deployments", and all pull requests in this direction will be merged post-haste.

## Getting Started

### Prerequisites

Make sure the following tools are installed and up to date before you begin. Older
releases are a common source of build and runtime issues.

- Docker Engine **25+** or Podman **4.9+**
- Docker Compose plugin **2.17+** (or Podman Compose when using Podman)
- Access to pull container images from `ghcr.io`
- Access to [Docker Hub](https://hub.docker.com) for pulling dependencies and base images

You can confirm the installed versions with:

```bash
docker -v
docker compose version
```

### Prepare the environment

1. Copy the `template.env` file to `.env` in the project root.
2. Customize `.env` according to your requirements (optional but recommended).

### Run

- `docker compose pull` if you want to use pre-built images or `docker compose build` if you want to build your own (see the [Troubleshooting](#troubleshooting) section in case of errors)
- `docker compose up`
  - Add `-d` to run the services in the background
- Login to `https://localhost`
  - User: `admin@admin.test`
  - Password: `admin`

Keeping the image up-to-date with upstream should be as simple as running `docker compose pull`.

### Configuration

The `docker-compose.yml` file allows further configuration settings:

```
"MYSQL_HOST=db"
"MYSQL_USER=misp"
"MYSQL_PASSWORD=example"    # NOTE: This should be AlphaNum with no Special Chars. Otherwise, edit config files after first run.
"MYSQL_DATABASE=misp"
"MISP_MODULES_FQDN=http://misp-modules" # Set the MISP Modules FQDN, used for Enrichment_services_url/Import_services_url/Export_services_url
"SMTP_PORT=25"               # Override the outbound SMTP port if your mail relay does not listen on 25
"WORKERS=1"                 # Legacy variable controlling the number of parallel workers (use variables below instead)
"NUM_WORKERS_DEFAULT=5"     # To set the number of default workers
"NUM_WORKERS_PRIO=5"        # To set the number of prio workers
"NUM_WORKERS_EMAIL=5"       # To set the number of email workers
"NUM_WORKERS_UPDATE=1"      # To set the number of update workers
"NUM_WORKERS_CACHE=5"       # To set the number of cache workers
```

New options are added on a regular basis.

#### Environment variable behaviour

Set environment variables in .env to configure settings instead of in docker-compose.yml where possible. Setting the variables in .env will allow you to pull updates from Github without issues caused by a modified docker-compose.yml file, should there be an update for it.

Environment variable driven settings are enforced every time the misp-core container starts. This means that if you change the config.php file or database for a setting that has a set environment variable, it will be changed to the environment variable value upon next container start. Empty environment variables may have a safe default which is enforced instead.

If you push a change to add or remove an environment variable, please look in "core/files/etc/misp-docker/" for json files with "envars" in the name and adjust there.

#### Unset safe default settings behaviour

The misp-core container has definitions for minimum safe default settings which are set if needed each time the container starts. They will only be set if there is no existing entry in the config.php file or database for these settings. If you specify a custom value for any of these settings it will be respected. See the definitions of these in "core/files/etc/misp-docker" where the filenames contain the word "defaults".

#### Storing system settings in the DB

This container includes the "ENABLE_DB_SETTINGS" environment variable, which can be used to set "MISP.system_setting_db" to true or false. This changes the behaviour of where MISP chooses to store operator made settings changes; in config.php or in the system_settings database table. By default this is set to false.

If a setting is not defined in the DB, but is defined in config.php, it will be read out of config.php and used. This can sometimes lead to operator confusion, so please check both locations for values when troubleshooting.

If you change this setting from false to true, settings are not migrated from config.php to the database, but rather the above behaviour is relied upon.

While storing system settings in the DB works as expected most of the time, you may come across some instances where a particular setting MUST be set in the config.php file. We have tried to side-step this issue by prepopulating the config.php file with all of these settings, but there could be more. If you encounter any issues like this, please raise an issue, and try configuring the setting in the config.php file instead.

#### Overriding environment variable and unset safe default settings behaviours

If you are trying to accomplish something and the above behaviours get in the way, please let us know as this is not intended.

To override these behaviours edit the docker-compose.yml file's misp-core volume definitions to enable the "customize_misp.sh" behaviour (see the bottom of the Production section for details). The "customize_misp.sh" script triggers after the above behaviours complete and is an appropriate place to override a setting. It is suggested that you use the "/var/www/MISP/app/cake Admin setSetting" command to override a setting, as this tool is config.php file and database setting aware.

#### Adding a new setting and unsure what files to edit?

If it is just a default setting that is meant to be set if not already set by the user, add it in one of the `*.default.json` files.
If it is a setting controlled by an environment variable which is meant to override whatever is set, add it in one of the `*.envars.json` files (note that you can still specify a default value).

### MISP-Guard (optional)

[MISP-Guard](https://github.com/MISP/misp-guard) is a mitmproxy add-on designed to apply configurable filters that prevent the unintentional leakage of sensitive threat intelligence data while facilitating controlled information sharing.  

It is disabled by default, but can be enabled using compose profiles.

#### Enabling

1. Enable the profile in your `.env` file:

```bash
COMPOSE_PROFILES=misp-guard
```

2. Ensure `misp-core` is configured to use a proxy:

```bash
PROXY_ENABLE=true
PROXY_HOST=misp-guard
# this must match GUARD_PORT (DEFAULT=8888)
PROXY_PORT=8888
```

#### Configuration

- Rules are defined in `guard/config.json`.
- The container automatically replaces the `misp-core` IP at runtime using `entrypoint.sh`.

The following format is required to target the misp-core, the IP is replaced with the misp-core container's IP at runtime.

```json
{
    "instances": {
        "misp_container": {
            "ip": "placeholder"
         }
    }
}
```

- After making changes to `guard/config.json` restart the container to apply the changes:

```bash
docker compose restart misp-guard
```

#### Environment Variables

```bash
# Port for misp-guard to listen on (must match PROXY_PORT)
# Default: 8888
GUARD_PORT=8888

# optional: mitmdump misp-guard runtime arguments (space separated)
GUARD_ARGS=--ssl-insecure -v
```

### Authentication

#### LDAP Authentication

You can configure LDAP authentication in MISP using 2 methods:

- native plugin: LdapAuth (<https://github.com/MISP/MISP/tree/2.5/app/Plugin/LdapAuth>)
- previous approach with ApacheSecureAuth (<https://gist.github.com/Kagee/f35ed25216369481437210753959d372>).

LdapAuth is recommended over ApacheSecureAuth because it doesn't require rproxy apache with the ldap module.

#### OIDC Authentication

OIDC Auth is implemented through the MISP OidcAuth plugin.

For example configuration using KeyCloak, see [MISP Keycloak 26.1.x Basic Integration Guide](docs/keycloak-integration-guide.md)

For Okta, create a new application integration:
  - Applications -> Applications -> Create App Integration
  - Select Sign-in method "OIDC - OpenID Connect" and Application type "Web Application"
  - In Client Authentication, select "Client secret"
  - Set the Sign-in redirect URI to: "https://<MISP_URL>/users/login"
  - Under the Sign-in tab, add a group claim called "roles" and an appropriate filter
  - In MISP docker `.env` file, set the following variables:
      ```
      OIDC_ENABLE=true
      OIDC_PROVIDER_URL=https://<OKTA_ORG_URL>/.well-known/openid-configuration
      OIDC_ISSUER=https://<OKTA_ORG_URL>
      OIDC_CLIENT_ID=[client_id]
      OIDC_CLIENT_SECRET=[client_secret]
      OIDC_ROLES_PROPERTY="roles" 
      OIDC_ROLES_MAPPING="{\"Okta group - MISP Admin\": 1}"  # 
      OIDC_DEFAULT_ORG="[Your default org in MISP]"
      #OIDC_LOGOUT_URL= 
      OIDC_SCOPES="[\"profile\", \"email\", \"groups\"]"
      OIDC_MIXEDAUTH=true  # (Set this to false if you want to disable password login, make sure OIDC is working first)
      OIDC_CODE_CHALLENGE_METHOD=S256
      OIDC_AUTH_METHOD="client_secret_post"  
      OIDC_REDIRECT_URI="https://<MISP_URL>/users/login" # (same value set in Okta)
      OIDC_DISABLE_REQUEST_OBJECT=false
      OIDC_SKIP_PROXY=true
      ``` 
 Valid options for OIDC_AUTH_METHOD are:
   - client_secret_post: tested
   - client_secret_basic: the default if variable is not set, but seems broken with Okta. It will return the following error: _"Error 'invalid_request' received from IdP: Cannot supply multiple client credentials"_.
   - client_secret_jwt: *not tested* 
   - private_key_jwt: *not tested* 


### Production

- It is recommended to specify the build you want run by editing `docker-compose.yml` (see here for the list of available tags <https://github.com/orgs/MISP/packages>)
- Directory volume mount SSL Certs `./ssl`: `/etc/ssl/certs`
  - Certificate File: `cert.pem`
  - Certificate Key File: `key.pem`
  - CA File for Cert Authentication (optional) `ca.pem`
- Additional directory volume mounts:
  - `./configs`: `/var/www/MISP/app/Config/`
  - `./logs`: `/var/www/MISP/app/tmp/logs/`
  - `./files`: `/var/www/MISP/app/files/`
  - `./gnupg`: `/var/www/MISP/.gnupg/`
- If you need to automatically run additional steps each time the container starts, create a new file `files/customize_misp.sh`, and replace the variable `${CUSTOM_PATH}` inside `docker-compose.yml` with its parent path.
- If you are interested in running streamlined versions of the images (fewer dependencies, easier approval from compliance), you might want to use the `latest-slim` tag. Just adjust the `docker-compose.yml` file, and run again `docker compose pull` and `docker compose up`.

### Build Options

This project supports multiple build methods to suit different needs.

#### Using Docker Compose (Standard Method)

For most users, the standard Docker Compose build is recommended:
```bash
docker compose build
```

#### Using Docker Buildx Bake (Advanced)

Docker Buildx bake provides advanced build capabilities including multi-platform builds and parallel building of multiple targets. This method uses the `docker-bake.hcl` configuration file.

**Prerequisites:**
- Docker Buildx plugin installed and enabled
- `template.env` file in the project root

**Build full-featured images:**
```bash
export NAMESPACE=local
export COMMIT_HASH=`git rev-parse --short HEAD`
sed -e '/^[[:space:]]*$/d' -e '/[#@]/d' -e 's/\"//g' -e 's/\(^[^=]*\)=\(.*\)/\1="\2"/' template.env > env.hcl
docker buildx bake -f docker-bake.hcl -f env.hcl --provenance false debian
```

This builds `misp-core`, `misp-modules`, and `misp-guard` with all features included.

**Build slim images:**
```bash
export NAMESPACE=local
export COMMIT_HASH=`git rev-parse --short HEAD`
sed -e '/^[[:space:]]*$/d' -e '/[#@]/d' -e 's/\"//g' -e 's/\(^[^=]*\)=\(.*\)/\1="\2"/' template.env > env.hcl
docker buildx bake -f docker-bake.hcl -f env.hcl --provenance false debian-slim
```

This builds lightweight versions of `misp-core-slim`, `misp-modules-slim`, and `misp-guard` with reduced dependencies.

**Available bake targets:**
- `standard` - Full-featured images (misp-core, misp-modules, misp-guard)
- `slim` - Lightweight images (misp-core-slim, misp-modules-slim, misp-guard)
- `default` - Builds all variants (both standard and slim)

**Note:** The (GNU) `sed` command converts `template.env` to `env.hcl` format by removing empty lines, comments, and properly formatting variables for the bake file (on OSX you should install `gsed`).

**After building with buildx bake:**

You can still use Docker Compose to run the services:
```bash
docker compose up
```
#### Using slow disks as volume mounts

Using a slow disk as the mounted volume or a volume with high latency like NFS, EFS or S3 might significantly increase the startup time and downgrade the performance of the service. To address this we will mount the bare minimum that needs to be persisted.

- Remove the `/var/www/MISP/app/files/` volume mount.
- Add the following volume mounts instead:
  - `./img/`: `/var/www/MISP/app/files/img`
  - `./terms`: `/var/www/MISP/app/files/terms`
  - `./attachments`: `/var/www/MISP/app/attachments`
- Set the environment variable `ATTACHMENTS_DIR` to the above folder location (it is important that it doesn't replace the `/var/www/MISP/app/files/` folder).

### SELinux

On systems using SELinux, volume binds are not given write permissions by default. Using the tag `:Z` or `:z` at the end of a volume bind files grants write permission through SELinux.

- The `Z` option tells Docker to label the content with a private unshared label.
- The `z` option tells Docker that two containers share the volume content.

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

## Database Management

It is possible to backup and restore the underlying database using volume archiving.
The process is *NOT* battle-tested, so it is *NOT* to be followed uncritically.

### Backup

1. Stop the MISP containers:

   ```bash
   docker compose down
   ```

2. Create an archive of the `misp-docker_mysql_data` volume using `tar`:

   ```bash
   tar -cvzf /root/misp_mysql_backup.tar.gz /var/lib/docker/volumes/misp-docker_mysql_data/
   ```

3. Start the MISP containers:

   ```bash
   docker compose up
   ```

### Restore

1. Stop the MISP containers:

   ```bash
   docker compose down
   ```

2. Unpack the backup and overwrite existing data by using the `--overwrite` option to replace existing files:

   ```bash
   tar -xvzf /path_to_backup/misp_mysql_backup.tar.gz -C /var/lib/docker/volumes/misp-docker_mysql_data/ --overwrite
   ```

3. Start the MISP containers:

   ```bash
   docker compose up
   ```

## Troubleshooting

- Make sure you run a fairly recent version of Docker and Docker Compose (if in doubt, update following the steps outlined in <https://docs.docker.com/engine/install/ubuntu/>)
- Make sure you are not running an old image or container; when in doubt run `docker system prune --volumes` and clone this repository into an empty directory
- If you receive an error that the 'start_interval' does not match any of the regexes, update Docker following the steps outlined in <https://docs.docker.com/engine/install/ubuntu/>)
- See below under **The image build fails or the image builds, but the container fails to start. Now what?**

## Versioning

A GitHub Action builds `misp-core`, `misp-modules`, and `misp-guard` images automatically and pushes them to the [GitHub Package registry](https://github.com/orgs/MISP/packages). We do not use tags inside the repository; instead we tag images as they are pushed to the registry. For each build, `misp-core`, `misp-modules`, `misp-guard` images are tagged as follows:

- `misp-core:${commit-sha1}[0:7]`, `misp-modules:${commit-sha1}[0:7]`, and `misp-guard:${commit-sha1}[0:7]` where `${commit-sha1}` is the commit hash triggering the build
- `misp-core:latest`, `misp-modules:latest`, and `misp-guard:latest` in order to track the latest builds available
- `misp-core:${CORE_TAG}`, `misp-modules:${MODULES_TAG}`, and `misp-guard:${GUARD_TAG}` reflecting the underlying versions as specified inside the `template.env` file at build time.

## Podman (experimental)

It is possible to run the image using `podman-systemd` rather than `docker` to:

- Run containers in **rootless** mode
- Manage containers with **systemd**
- Write container descriptions in an **ignition** file and deploy them (not covered in this documentation)

Note that this is **experimental** and it is **NOT SUPPORTED** (issues will be automatically closed).

### Configuration

Copy the following directories and files:

- Content of `experimental/podman-systemd` to `$USER/.config/containers/systemd/`
- `template.vars` to `$USER/.config/containers/systemd/misp.env`
- Create `misp-modules` folders

```bash
mkdir -p $HOME/.config/misp_conf/custom/{action_mod,expansion,export_mod,import_mod}
```

Edit `misp.env`, and initialize the following MySQL settings:

```bash
MYSQL_HOST=
MYSQL_USER=
MYSQL_PASSWORD=
MYSQL_ROOT_PASSWORD=
MYSQL_DATABASE=
```

Set the Redis password:

```bash
REDIS_PASSWORD=
```

Enable passwordless Redis connection (defaults to false for security):

```bash
ENABLE_REDIS_EMPTY_PASSWORD=false
```

Set the base URL:

```bash
BASE_URL=https://<IP>:10443
```

### Run

Reload systemd user daemon:

```bash
systemctl --user daemon-reload
```

Start services:

```bash
systemctl --user start misp-mail.service
systemctl --user start misp-db.service
systemctl --user start misp-redis.service
systemctl --user start misp-core.service
systemctl --user start misp-modules.service
```

Wait a bit and check your service at `https://<IP>:10443`.
If everything checks out, you can make services persistent across reboots and logouts:

```bash
sudo loginctl enable-linger $USER
```

You can even set podman to check for new container versions by activating the specific timer `podman-auto-update.timer`:

```bash
systemctl --user enable podman-auto-update.timer --now
```

# The image build fails or the image builds, but the container fails to start. Now what?

If your image build fails or the build completes successfully but the container fails to start, you can get help by creating a new [issue](https://github.com/MISP/misp-docker/issues). To receive the most effective support, please include the conditions under which you attempted to build the images, along with relevant debug output.

## Provide your build environment details

Be sure to include the versions of your build environment, such as Docker (or Podman), Docker Compose (or Podman Compose), Python, your operating system, and whether you are building as root or a non-root user.

For **Docker**, run:

```
python3 -V
docker -v
docker compose version
```

For **Podman**, run:

```
python3 -V
podman -v
podman compose version
```

## Always start from a clean environment

Build errors can occur if incomplete layers remain from previous builds. To ensure a clean environment, stop all running containers and remove old images and volumes.

With **Docker**:

```
docker compose down
docker system prune
docker image rm ghcr.io/misp/misp-docker/misp-core
docker image rm ghcr.io/misp/misp-docker/misp-modules
docker image rm ghcr.io/misp/misp-docker/misp-guard
```

With **Podman**:

```
podman compose down
podman system prune
podman image rm ghcr.io/misp/misp-docker/misp-core
podman image rm ghcr.io/misp/misp-docker/misp-modules
podman image rm ghcr.io/misp/misp-docker/misp-guard
```

You can also use the `--no-cache` option during the build to ignore cached layers.

## Log the build output

After cleaning your environment, use verbose logging to capture detailed output from the build process. Logging to a file is recommended for troubleshooting and **when requesting support**.

For **Docker**:

```
docker compose --verbose build --no-cache | tee build.log
```

For **Podman**:

```
PODMAN_COMPOSE_VERBOSE=1 podman compose build --no-cache | tee build.log
```

## Bringing it all together

You can combine the above commands to fully reset and rebuild the images in one step.

For **Docker**:

```
docker system prune ; docker image rm ghcr.io/misp/misp-docker/misp-core ; docker image rm ghcr.io/misp/misp-docker/misp-modules ;  docker image rm ghcr.io/misp/misp-docker/misp-guard ; rm -f build.log ; docker compose --verbose build --no-cache | tee build.log
```

For **Podman**:

```
podman system prune ; podman image rm ghcr.io/misp/misp-docker/misp-core ; podman image rm ghcr.io/misp/misp-docker/misp-modules ; podman image rm ghcr.io/misp/misp-docker/misp-guard ; rm -f build.log ; PODMAN_COMPOSE_VERBOSE=1 podman compose build --no-cache | tee build.log
```

This ensures you are building from a clean state and not using remnants from previous builds.

## Debugging the Dockerfile

With your build log, you can identify where the build fails. To pinpoint the exact step, add debug lines to the Dockerfile. Use unique markers to make them easy to find in the log:

```
RUN echo "____MYDEBUG___1"
RUN echo "____MYDEBUG___2"
RUN echo "____MYDEBUG___3"
```

### Print variable values

Many build errors are related to variables not being set or imported correctly. To debug, print their values:

```
RUN echo "____MYDEBUG___ CORE_TAG: ${CORE_TAG}"
```

Example output:

```
[4/5] STEP 19/20: RUN echo "____MYDEBUG___ CORE_TAG: ${CORE_TAG}"
____MYDEBUG___ CORE_TAG: v2.5.16
--> 798999451f75
```

### Print variables inside shell blocks

For shell blocks in the Dockerfile, insert `echo` statements to print variable values:

```
RUN <<-EOF
    for mod in "$@"; do
        mod_version_var=$(echo "PYPI_${mod}_VERSION" | tr '[:lower:]' '[:upper:]' | tr '-' '_')
        mod_version=$(eval "echo \"\$$mod_version_var\"")
        echo "____MYDEBUG___ mod mod_version: ${mod}${mod_version}"
        # ... rest of the code ...
    done
EOF
```

### Variables not expanding

Older versions (pre version 5) of Podman may not expand variables correctly inside shell blocks. If you encounter this, ensure you are using the correct shell syntax. For Podman, replace:

```
RUN <<-EOF
```

with (also notice the **'** quotes)

```
RUN bash <<-'EOF'
```

to ensure variables are expanded as expected. For reference, this problem first occurred after successfully building an image but getting a `/usr/local/bin/supervisord: No such file or directory` error after starting the container. See [265](https://github.com/MISP/misp-docker/issues/265) and [273](https://github.com/MISP/misp-docker/pull/273) for more details.

By following these steps, you can efficiently troubleshoot and resolve build issues. If problems persist, include your build log and environment details when opening an issue for assistance.
