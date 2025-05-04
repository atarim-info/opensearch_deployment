# OpenSearch Kubernetes Deployment - Production Overlay

This overlay is intended for production environments.

## Description

- Uses the base OpenSearch manifests.
- Applies resource and replica patches suitable for production.
- Includes ingress configuration.
- Deploys resources into the `opensearch-prod` namespace.
- Includes common labels for production environment.

## How to Deploy

1. Ensure the `opensearch-prod` namespace exists:

```bash
kubectl create namespace opensearch-prod
```

2. Apply the overlay using kustomize:

```bash
kubectl apply -k infra/opensearch-k8s/overlays/production
```

## Notes

- Resource limits and replica counts are set for production workloads.
- Ingress is configured for external access.
- Ensure proper TLS and security configurations are applied.
