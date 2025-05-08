# setup-wsl-opensearch.sh
#!/bin/bash

# Setup script for WSL single node OpenSearch deployment
# This script creates a local directory for OpenSearch data and configures the necessary Kubernetes resources.
# This script is designed to be run in a WSL environment with Kubernetes and kubectl installed.


# Create directories
sudo mkdir -p /mnt/opensearch/node-0
sudo chmod 777 /mnt/opensearch/node-0

# Get node name
NODE_NAME=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
echo "Your node name is: $NODE_NAME"

# Replace node name in PV file
sed -i "s/YOUR_NODE_NAME/$NODE_NAME/g" base/local-pv-wsl.yaml

# Apply storage class and PV
kubectl apply -f base/local-storage.yaml
kubectl apply -f base/local-pv-wsl.yaml

# Deploy OpenSearch
kubectl apply -k overlays/wsl

echo "OpenSearch deployment started. Check status with:"
echo "kubectl get pods -n opensearch-wsl"