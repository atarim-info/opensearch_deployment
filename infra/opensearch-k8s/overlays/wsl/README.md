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

2. Generate and apply secrets and certificates:

```bash
bash infra/opensearch-k8s/scripts/generate-self-signed-certs.sh
kubectl apply -f infra/opensearch-k8s/base/secrets.yaml
```

3. Set up local persistent volumes compatible with WSL:

```bash
bash infra/opensearch-k8s/scripts/setup-local-pv.sh
```

4. Apply the WSL overlay using kustomize:

```bash
kubectl apply -k infra/opensearch-k8s/overlays/wsl
```

5. To access the OpenSearch Dashboard from the hosting machine, run:

```bash
kubectl port-forward service/opensearch-dashboard 5601:5601 -n opensearch-wsl &
```

## Notes

- Uses local storage and persistent volumes compatible with WSL.
- Suitable for local development and testing on Windows machines.
- Includes a setup script `setup-wsl-opensearch.sh` for environment preparation.
- Customize secrets and config maps as needed in the base manifests.
