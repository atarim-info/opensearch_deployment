# OpenSearch Kubernetes Deployment

This repository contains Kubernetes manifests and overlays for deploying OpenSearch clusters in different environments using Kustomize.

## Directory Structure

- `base/`: Base manifests for OpenSearch components including statefulsets, services, dashboard, secrets, and configmaps.
- `overlays/`: Environment-specific overlays that customize the base manifests for different deployment scenarios.
  - `development/`: Overlay for development environment with reduced resource usage and replica counts.
  - `production/`: Overlay for production environment with ingress and production-grade resource settings.
  - `wsl/`: Overlay for running OpenSearch on Windows Subsystem for Linux (WSL) with local persistent volumes and single-node setup.

## Deployment

### Development

Deploy the development environment overlay:

```bash
kubectl create namespace opensearch-dev
kubectl apply -k infra/opensearch-k8s/overlays/development
```

### Production

Deploy the production environment overlay:

```bash
kubectl create namespace opensearch-prod
kubectl apply -k infra/opensearch-k8s/overlays/production
```

### WSL

Deploy the WSL environment overlay:

```bash
kubectl create namespace opensearch-wsl
kubectl apply -k infra/opensearch-k8s/overlays/wsl
```

## Notes

- Ensure the target namespaces exist before applying overlays.
- Customize resource limits and replica counts as needed in overlays.
- Use the provided setup scripts in the WSL overlay for environment preparation.
- Secrets are managed in the base manifests and can be customized as needed.

## Additional Resources

- Refer to the README.md files in each overlay directory for environment-specific details.
- Review the base manifests for core OpenSearch configuration.

## Troubleshooting

- Namespace transformation errors often result from mismatched namespaces in base and overlays.
- Ensure no duplicate resource definitions exist across overlays.
- Clear Kustomize cache or use `--reorder=none` if encountering resource ID conflicts.

For further assistance, please consult the project documentation or contact the maintainers.
