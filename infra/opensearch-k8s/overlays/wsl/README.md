# OpenSearch Kubernetes Deployment - WSL Overlay

This overlay is intended for running OpenSearch on Windows Subsystem for Linux (WSL).

## Description

- Uses the base OpenSearch manifests with local persistent volumes suitable for WSL.
- Deploys a single-node OpenSearch cluster.
- Deploys resources into the `opensearch-wsl` namespace.
- Generates config map and secrets specific to WSL environment.

## How to Deploy

1. Ensure the `opensearch-wsl` namespace exists:

```bash
kubectl create namespace opensearch-wsl
```

2. Apply the overlay using kustomize:

```bash
kubectl apply -k infra/opensearch-k8s/overlays/wsl
```

## Notes

- Uses local storage and persistent volumes compatible with WSL.
- Suitable for local development and testing on Windows machines.
- Includes a setup script `setup-wsl-opensearch.sh` for environment preparation.
