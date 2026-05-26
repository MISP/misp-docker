# MISP kubernetes manifests

These are minimum viable kubernetes manifests for

- MISP [deployment](./manifests/deployment-misp.yaml)
- Nginx [deployment](./manifests/deployment-nginx.yaml)
- MySQL [statefulset](./manifests/mysql.yaml)
- Redis [deployment](./manifests/redis.yaml)
- Associated [services](./manifests/services.yaml)
- [CronJobs](./manifests/cronjobs/) for various housekeeping tasks

There is also an [example network policy](./manifests/policy-cilium.yaml) (Cilium specific) that assumes the use of ingress-nginx in the ingress-nginx namespace to expose MISP.

Optionally there is a MISP-Guard proxy [Component](./components/misp-guard/).

The manifests and required secrets can be generated through [kustomize](./kustomization.yaml).

## Usage

1. Edit [instance-secrets.env](./instance-secrets.env). Optionally introduce other settings documented i [template.env](../template.env)
    - If S3_ variables are defined, MISP will store event attachments in the specified bucket.
    - To instead store locally, remove any S3_ variables an ensure you mount a PVC at `/var/www/MISP/app/files`
1. Edit [mysql-credentials.env](./mysql-credentials.env) to set your desired database credentials.
1. Build and apply all the manifests to the cluster: `kustomize build . | kubectl apply -f -`

It is highly recommended to use a database operator such as Percona instead of relying on the example mysql statefulset found here.

This kustomize can also be used as a base for further customization, e.g. one that overrides instance-secrets:

```yaml
# kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
 - 'https://github.com/MISP/misp-docker.git/kubernetes?ref=master'

generators:
  - ./custom-instance-generator.yaml
---
# custom-instance-generator.yaml
apiVersion: builtin
kind: SecretGenerator
metadata:
  name: instance-secrets
literals:
  - SUPERVISOR_HOST=remote-host.fqdn
behavior: merge
```

This will then override or add the SUPERVISOR_HOST, while keeping everything else due to the `merge` behavior.

### Storage

By default these manifests assume the use of S3 based attachment storage (see `S3_*` keys in [instance-secrets.env](./instance-secrets.env)).

If these variables are not all supplied, the default is for MISP to store attachment data in `/var/www/MISP/app/files/`. This should be backed by a persistentVolumeClaim of your preferred storageclass named `misp-files`.

## MISP-Guard

Information on MISP-Guard's configuration and environment variables can be found in the root [README](../README.md#misp-guard-optional).

### Enabling

Add the following to your `kustomization.yaml`:

```yaml
components:
  - ./components/misp-guard
```

### Configuration

Edit the [misp-guard-config](./components/misp-guard/guard-cm.yaml) ConfigMap with your instance details. 
The `misp_container` IP is automatically resolved at runtime via the `misp-core-svc` service.

### Applying

```bash
kustomize build . | kubectl apply -f -
kubectl rollout restart deployment misp-guard
```