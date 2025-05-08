# Script to create local directories
---
#!/bin/bash
# setup-local-pv.sh

# Create base directory
sudo mkdir -p /mnt/opensearch

# Create directories for master nodes
for i in {0..2}; do
  sudo mkdir -p /mnt/opensearch/master-$i
  sudo chmod 777 /mnt/opensearch/master-$i
done

# Create directories for data nodes
for i in {0..1}; do
  sudo mkdir -p /mnt/opensearch/data-$i
  sudo chmod 777 /mnt/opensearch/data-$i
done

echo "Local directories created for OpenSearch PVs"

# Get node name for configuration
NODE_NAME=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
echo "Your node name is: $NODE_NAME"
echo "Please replace 'YOUR_NODE_NAME' in the PV YAML files with: $NODE_NAME"
