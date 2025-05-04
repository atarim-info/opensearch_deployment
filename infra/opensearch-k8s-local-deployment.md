# Setting Up OpenSearch with Manual PVs on WSL Kubernetes

This guide explains how to set up Persistent Volumes (PVs) manually for OpenSearch on a local WSL Kubernetes environment.

## Prerequisites

- WSL2 with a Linux distribution (Ubuntu recommended)
- Kubernetes cluster running on WSL (minikube, k3s, or kind)
- `kubectl` configured to access your cluster

## Step 1: Create Local Storage Directories

First, create the necessary directories that will be used as storage locations for your PVs:

```bash
# Save this as setup-local-pv.sh and make it executable (chmod +x setup-local-pv.sh)
#!/bin/bash

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
echo "Please replace 'YOUR_NODE_NAME' in the PV YAML files with this value"
```

Run the script:

```bash
./setup-local-pv.sh
```

## Step 2: Create the StorageClass and PVs

Apply the local storage class:

```bash
kubectl apply -f base/local-storage.yaml
```

Update the node name in your PV definitions:

```bash
# Replace YOUR_NODE_NAME with your actual node name in the PV files
NODE_NAME=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
sed -i "s/YOUR_NODE_NAME/$NODE_NAME/g" base/local-pv-master.yaml
sed -i "s/YOUR_NODE_NAME/$NODE_NAME/g" base/local-pv-data.yaml
```

Apply the PV definitions:

```bash
kubectl apply -f base/local-pv-master.yaml
kubectl apply -f base/local-pv-data.yaml
```

## Step 3: Update Your Kustomization Files

Make sure your kustomization.yaml includes the local storage resources:

```yaml
# base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- namespace.yaml
- local-storage.yaml
- local-pv-master.yaml
- local-pv-data.yaml
- configmap.yaml
- secrets.yaml
- services/
- statefulsets/
- dashboard/

commonLabels:
  app.kubernetes.io/name: opensearch
  app.kubernetes.io/part-of: opensearch-cluster
```

## Step 4: Update StatefulSet Configurations

Ensure your StatefulSets reference the local storage class:

```yaml
# In base/statefulsets/master-statefulset.yaml and data-statefulset.yaml
volumeClaimTemplates:
- metadata:
    name: data
  spec:
    accessModes: [ "ReadWriteOnce" ]
    storageClassName: local-storage  # Using local storage
    resources:
      requests:
        storage: 10Gi  # Adjust size as needed
```

## Step 5: Adapt for WSL Resource Constraints

For WSL environments, it's recommended to reduce the resource requirements:

1. Reduce the number of replicas:

```yaml
# In overlays/development/replicas-patch.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: opensearch-cluster-master
spec:
  replicas: 1  # Single master for local testing
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: opensearch-cluster-data
spec:
  replicas: 1  # Single data node for local testing
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: opensearch-cluster-client
spec:
  replicas: 1  # Single client node for local testing
```

2. Reduce resource requests:

```yaml
# In overlays/development/resource-patch.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: opensearch-cluster-master
spec:
  template:
    spec:
      containers:
      - name: opensearch
        resources:
          limits:
            cpu: 500m
            memory: 1Gi
          requests:
            cpu: 200m
            memory: 512Mi
        env:
        - name: JVM_HEAP_SIZE
          value: "512m"
```

## Step 6: Deploy OpenSearch

Apply your customized configuration:

```bash
# For development/local environment
kubectl apply -k opensearch-k8s/overlays/development
```

## Step 7: Verify the Deployment

Check if PVs are bound:

```bash
kubectl get pv,pvc -n opensearch-dev
```

Check if pods are running:

```bash
kubectl get pods -n opensearch-dev
```

## Troubleshooting

### PVC Binding Issues

If PVCs are not binding to PVs:

1. Verify node affinity in PVs matches your node name:
   ```bash
   kubectl describe pv opensearch-master-pv-0
   ```

2. Check PVC requests:
   ```bash
   kubectl describe pvc data-opensearch-cluster-master-0 -n opensearch-dev
   ```

### Pod Scheduling Issues

If pods are pending:

1. Check events:
   ```bash
   kubectl get events -n opensearch-dev
   ```

2. Describe the pod:
   ```bash
   kubectl describe pod opensearch-cluster-master-0 -n opensearch-dev
   ```

### OpenSearch Cluster Not Forming

If OpenSearch pods are running but the cluster isn't forming:

1. Check logs:
   ```bash
   kubectl logs opensearch-cluster-master-0 -n opensearch-dev
   ```

2. Adjust discovery settings in configmap.yaml for a single-node cluster:
   ```yaml
   discovery.type: single-node
   ```

## Performance Considerations for WSL

- WSL has limited resources compared to a production environment
- JVM heap size should be reduced (e.g., 512m instead of 4g)
- Run a minimal setup (1 master, 1 data node)
- Disable unnecessary plugins

By following these steps, you should have a working OpenSearch deployment on your local WSL Kubernetes environment with manually created Persistent Volumes.
