# MISP stunnel Guide #

This guide provides some basic examples of how to use the [stunnel](https://www.stunnel.org/) functionality provided in the misp-docker image.

## Enabling ##

`template.env` contains two stunnel related variables:
| Variable       | Values           | Default | Purpose                                                                    |
| :------------- | :--------------- | :------ | :------------------------------------------------------------------------- |
| STUNNEL        | `true`/`false`   | `false` | If true will start the stunnel service on container start, via supervisord |
| STUNNEL_CONFIG | File path string |         | Must contain a file path to a stunnel config file                          |

If `STUNNEL` is `true` but `STUNNEL_CONFIG` is unset, empty or otherwise does not point to a config file, supervisord will retry starting the service a few times before failing.

## Configuration ##

You can find the stunnel configuration documentation [here](https://www.stunnel.org/static/stunnel.html), and general examples [here](https://www.stunnel.org/examples.html).

## Example: Redis over TLS ##

This example demonstrates how misp-docker's Redis (Valkey) container might be configured to use TLS, and how to leverage the stunnel functionality to communicate with it over TLS.

The general idea here is that stunnel will expose a plaintext port for the MISP codebase to talk Redis over, which will then be proxied to the `redis` container's TLS speaking port. Traffic across the containers will be via TLS as a result. You could just as easily point to an AWS Elasticache or other external Redis instance with the benefit of TLS encryption.

This example largely builds on [this](https://redis.io/blog/stunnel-secure-redis-ssl/) redis.io blog post.

### Steps: ###

#### Copy the example files into the root of your misp-docker project ####

If you have an existing directory named `misp_custom` or a `docker-compose.override.yml` file already, the below will mess with them. You may wish to manually add these things in that case.

Change into your misp-docker project dir first.

```
cp -r docs/examples/stunnel/redis/misp_custom .
cp docs/examples/stunnel/redis/docker-compose.override.yml .
```

The `docker-compose.override.yml` file will reference the files within the `misp_custom` directory, tell Redis to use TLS key files for TLS communications, and tell the health check to use it as well.

#### Roll some certificates ####

We will do this in the `misp_custom/redis_tls` directory using `gencerts.sh` which were copied from the last step:

```
cd misp_custom/redis_tls
./gencerts.sh
cd ../..
```

You should be left with a directory structure that looks like this:

```
tree misp_custom
misp_custom/
├── redis_tls
│   ├── ca-key.pem
│   ├── ca.pem
│   ├── ca.srl
│   ├── client-cert.pem
│   ├── client.csr
│   ├── client-key.pem
│   ├── gencerts.sh
│   ├── server-cert.pem
│   ├── server.csr
│   └── server-key.pem
└── stunnel
    └── stunnel.conf

3 directories, 11 files
```

#### Update .env file with necessary values ####

Edit your .env file so that the following envars are like this:

```
REDIS_HOST=localhost
STUNNEL=true
STUNNEL_CONFIG=/custom/stunnel/stunnel.conf
```

#### Bring up the compose project ####

```
docker compose up -d
```

You should now have TLS wrapped Redis, where the client and server are authenticating each other.

Check the Administration -> Server Settings & Maintenance -> Diagnostics tool for system status.

### Troubleshooting ###

Places to look for clues if you run into trouble:

* stunnel log files will appear in in the `logs` dir as `stunnel.log` and `stunnel-errors.log`
* Redis/valkey log output can be found in the `redis` container
* Supervisord log output can be found in the `misp-core` container
