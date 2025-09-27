# MISP kubernetes manifests

These are minimum viable kubernetes manifests for

- MISP [deployment](./manifests/deployment.yaml)
- MySQL [statefulset](./manifests/mysql.yaml)
- Redis [deployment](./manifests/redis.yaml)
- Associated [services](./manifests/services.yaml)
- [CronJobs](./manifests/cronjobs/) for various housekeeping tasks

There is also an [example network policy](./manifests/policy-cilium.yaml) (Cilium specific) that assumes the use of ingress-nginx in the ingress-nginx namespace.

The manifests and required secrets can be generated through [kustomize](./kustomization.yaml).

## Usage

1. Modify [instance-secrets](./instance-secrets.env) with desired secrets (optionally add desired environment variables)
2. Modify [mysql-credentials](./mysql-credentials.env) to set database credentials.
3. Build and apply all the manifests to the cluster: `kustomize build . | kubectl apply -f -`

It is highly recommended to use a database operator such as Percona instead of relying on the example mysql statefulset found here.

### Storage

By default these manifests assume the use of S3 based attachment storage (see `S3_*` keys in [instance-secrets](./instance-secrets.yaml)).

If these variables are not all supplied, the default is for MISP to store attachment data in `/var/www/MISP/app/files/`. This should be backed by a persistentVolumeClaim of your preferred storageclass named `misp-files`.