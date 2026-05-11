# MISP Helm Chart - Deployment Guide

## Overview

This Helm chart deploys MISP (Malware Information Sharing Platform) on Kubernetes with all required dependencies including MariaDB and Valkey (Redis alternative).

## Prerequisites

### Required Components

1. **Kubernetes Cluster** (v1.19 or higher)
2. **Helm** (v3.0 or higher)
3. **Ingress Controller** (e.g., nginx-ingress-controller)
4. **cert-manager** (for TLS certificate management)

### Storage

- A StorageClass must be available (default: `local-path`)
- Persistent volumes will be created for:
  - MISP data (5Gi)
  - MariaDB (5Gi)
  - Valkey/Redis (5Gi)

## Installation Steps

### 1. Install Ingress Controller

If you don't have an ingress controller installed:

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.12.0-beta.0/deploy/static/provider/cloud/deploy.yaml
```

Verify the ingress controller is running:

```bash
kubectl get pods -n ingress-nginx
```

### 2. Install cert-manager

cert-manager is required for automatic TLS certificate generation and management.

```bash
# Add the Jetstack Helm repository
helm repo add jetstack https://charts.jetstack.io
helm repo update

# Install cert-manager with CRDs
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set crds.enabled=true
```

Wait for cert-manager to be ready:

```bash
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=cert-manager -n cert-manager --timeout=120s
```

### 3. Create Certificate Issuer

Create a ClusterIssuer for self-signed certificates (for testing) or configure Let's Encrypt for production:

**Self-Signed (Development/Testing):**

```bash
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned-issuer
spec:
  selfSigned: {}
EOF
```

### 4. Configure DNS

Add a DNS entry or hosts file entry pointing to your ingress controller IP:

```bash
# Find your ingress controller IP
kubectl get svc -n ingress-nginx

# Add to /etc/hosts (Linux/macOS) or C:\Windows\System32\drivers\etc\hosts (Windows)
<INGRESS_IP> misp.devlab.local
```

### 5. Prepare Custom Scripts (Optional)

If you want to use custom initialization scripts, create a ConfigMap:

```bash
kubectl create configmap misp-customize \
  --from-file=customize_misp.sh=files/custom/customize_misp.sh \
  -n misp
```

### 6. Deploy MISP

```bash
# Update Helm dependencies
helm dependency update .

# Install or upgrade MISP
helm upgrade --install misp path/to/helm-chart \
  -n misp \
  --create-namespace
```

#### Custom Configuration

Create your own values file based on `values.yaml`:

```bash
cp values.yaml my-values.yaml
# Edit my-values.yaml with your settings
helm upgrade --install misp . -n misp --create-namespace -f my-values.yaml
```

### 7. Monitor Deployment

Watch the deployment progress:

```bash
# Check pod status
kubectl get pods -n misp -w

# Check MISP logs
kubectl logs -n misp -l app.kubernetes.io/name=misp -f

# Check initialization job
kubectl logs -n misp -l job-name=misp-misp-config -f
```

### 8. Access MISP

Once all pods are running, access MISP:

```bash
# Check ingress
kubectl get ingress -n misp

# Open in browser
https://misp.devlab.local
```

Default credentials (will be auto-generated if not specified):
- **Username**: `admin@misp.local` (configured via `mispConfig.initialAdminUsername`)
- **Password**: Check the secret or set via `auth.adminPassword`

```bash
# Retrieve auto-generated password
kubectl get secret misp-misp-secrets -n misp -o jsonpath='{.data.password}' | base64 -d
echo
```

## Configuration

### Key Configuration Options

#### Ingress Configuration

```yaml
misp:
  ingress:
    enabled: true
    className: "nginx"
    hosts:
      - host: "misp.example.com"
        paths:
          - path: "/"
            pathType: "ImplementationSpecific"
    annotations:
      cert-manager.io/cluster-issuer: "selfsigned-issuer"  # or "letsencrypt-prod"
      nginx.ingress.kubernetes.io/ssl-redirect: "true"
    tls:
      - hosts:
          - misp.example.com
        secretName: misp-tls
```

#### Custom Scripts

Enable custom initialization scripts:

```yaml
misp:
  mispConfig:
    customScripts:
      enabled: true
      configMapName: "misp-customize"
      mountPath: "/custom/files"
      runInBackground: true
      scripts:
        - "customize_misp.sh"
```

#### Resource Limits

Adjust resource allocation:

```yaml
misp:
  resources:
    requests:
      memory: "512Mi"
      cpu: "400m"
    limits:
      memory: "1024Mi"
      cpu: "1"
```

#### Database Configuration

MariaDB settings:

```yaml
mariadb:
  enabled: true
  auth:
    username: "misp"
    database: "misp"
    existingSecret: "misp-mariadb"
  resources:
    requests:
      cpu: "800m"
      memory: "1024Mi"
    limits:
      cpu: 1
      memory: "2048Mi"
```

## Troubleshooting

### Pod Not Starting

```bash
# Check pod events
kubectl describe pod -n misp -l app.kubernetes.io/name=misp

# Check logs
kubectl logs -n misp -l app.kubernetes.io/name=misp --all-containers
```

### Database Connection Issues

```bash
# Check MariaDB pod
kubectl get pods -n misp -l app.kubernetes.io/name=mariadb

# Test database connection
kubectl exec -it -n misp deployment/misp -- mysql -h misp-mariadb -u misp -p
```

### Certificate Issues

```bash
# Check certificate status
kubectl get certificate -n misp

# Check cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager
```

### Ingress Not Working

```bash
# Verify ingress controller
kubectl get pods -n ingress-nginx

# Check ingress resource
kubectl describe ingress -n misp

# Test from inside cluster
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl -k https://misp.misp.svc.cluster.local
```

## Upgrade

To upgrade an existing installation:

```bash
# Update dependencies
helm dependency update .

# Upgrade
helm upgrade misp . -n misp -f community-values.yaml

# Force pod restart if needed
kubectl rollout restart deployment/misp -n misp
```

## Uninstall

To completely remove MISP:

```bash
# Delete Helm release
helm uninstall misp -n misp

# Delete PVCs (optional - this will delete all data!)
kubectl delete pvc --all -n misp

# Delete namespace (optional)
kubectl delete namespace misp
```

## Advanced Configuration

### OIDC Authentication

Enable OIDC/Keycloak authentication:

```yaml
misp:
  auth:
    oidc:
      enable: true
      provider_url: "https://keycloak.example.com/realms/misp"
      client_id: "misp"
      roles_property: "misp-roles"
      roles_mapping: '{"misp-admin": "1", "misp-user": "3"}'
      default_org: "Demo"
```

### Custom CA Certificates

Add custom CA certificates:

```yaml
misp:
  mispConfig:
    extraCerts:
      enabled: true
      templatePath: misp/templates
      configMapFile: extra-certs.yaml
```

### Network Policies

Enable network policies for enhanced security:

```yaml
misp:
  networkPolicy:
    enabled: true
    allowExternal: false
```

## Security Considerations

1. **Change Default Passwords**: Always set custom passwords for production
2. **Use TLS**: Enable TLS with valid certificates (Let's Encrypt)
3. **Network Policies**: Enable network policies to restrict traffic
4. **Resource Limits**: Set appropriate resource limits to prevent DoS
5. **Regular Updates**: Keep MISP and dependencies up to date
6. **Backup**: Implement regular backup strategy for PVCs
7. **Secret Management**: Consider using Vault for secret management
