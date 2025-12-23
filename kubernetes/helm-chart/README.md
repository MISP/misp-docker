# MISP Helm chart

## Usage

```sh
# Lint chart
helm lint .

# Package chart
helm package .

# Add repo
helm repo add misp https://gitlab.com/api/v4/projects/64679397/packages/helm/stable

# Install
helm install misp/misp
```

## Custom Scripts

This Helm chart supports custom scripts execution after MISP initialization, similar to the `CUSTOM_PATH` feature in the MISP Docker setup.

### Configuration

Enable custom scripts in your `values.yaml`:

```yaml
misp:
  mispConfig:
    customScripts:
      enabled: true
      configMapName: "misp-custom-scripts"
      mountPath: "/custom"
      scripts:
        - "customize_misp.sh"
        - "custom_config.py"
```

### Adding Custom Scripts

1. Place your scripts in the `files/custom/` directory
2. Supported file types: `.sh`, `.py`, `.php`
3. Scripts are automatically made executable
4. Use environment variables for configuration

### Example Environment Variables

```yaml
misp:
  mispConfig:
    extraVars:
      CUSTOM_ORG_NAME: "My Organization"
      CUSTOM_TAGS: "internal,critical,malware"
      UPDATE_WARNINGLISTS: "true"
      CREATE_SAMPLE_EVENT: "true"
```

See `files/custom/README.md` for detailed documentation and examples.

## Parameters
