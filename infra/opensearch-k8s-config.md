# OpenSearch on Kubernetes: Kustomize-based Deployment Guide

This guide provides a customizable configuration for deploying OpenSearch on Kubernetes using Kustomize. It includes Kubernetes manifests for a complete OpenSearch cluster with customizable parameters organized in a proper folder hierarchy.

## Table of Contents
- [Prerequisites](#prerequisites)
- [Architecture Overview](#architecture-overview)
- [Directory Structure](#directory-structure)
- [Kustomization Files](#kustomization-files)
- [Configuration Files](#configuration-files)
  - [Storage Class](#storage-class)
  - [Namespace](#namespace)
  - [Secrets](#secrets)
  - [ConfigMap](#configmap)
  - [Service](#service)
  - [StatefulSet](#statefulset)
  - [Ingress](#ingress)
  - [OpenSearch Dashboard](#opensearch-dashboard)
- [Deployment Instructions](#deployment-instructions)
- [Customization Options](#customization-options)

## Prerequisites

- Kubernetes cluster (v1.19+)
- kubectl installed and configured with kustomize capability
- Kubernetes Ingress controller (optional, for external access)
- Persistent storage option available in your cluster

## Architecture Overview

The deployment consists of:
- OpenSearch master nodes
- OpenSearch data nodes
- OpenSearch client/coordinator nodes
- OpenSearch Dashboard
- Internal transport network
- External REST API service

## Directory Structure

```
opensearch-k8s/
├── base/
│   ├── kustomization.yaml
│   ├── namespace.yaml
│   ├── storageclass.yaml
│   ├── configmap.yaml
│   ├── secrets.yaml
│   ├── services/
│   │   ├── kustomization.yaml
│   │   ├── cluster-service.yaml
│   │   └── headless-service.yaml
│   ├── statefulsets/
│   │   ├── kustomization.yaml
│   │   ├── master-statefulset.yaml
│   │   ├── data-statefulset.yaml
│   │   └── client-statefulset.yaml
│   └── dashboard/
│       ├── kustomization.yaml
│       ├── deployment.yaml
│       └── service.yaml
├── overlays/
│   ├── development/
│   │   ├── kustomization.yaml
│   │   ├── resource-patch.yaml
│   │   └── replicas-patch.yaml
│   └── production/
│       ├── kustomization.yaml
│       ├── resource-patch.yaml
│       ├── replicas-patch.yaml
│       └── ingress.yaml
└── README.md
```

## Kustomization Files

### Storage Class

```yaml
# opensearch-storageclass.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: opensearch-storage
provisioner: kubernetes.io/aws-ebs  # Change based on your cloud provider
parameters:
  type: gp2
  fsType: ext4
reclaimPolicy: Retain
allowVolumeExpansion: true
```

### Namespace

```yaml
# opensearch-namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: opensearch
  labels:
    name: opensearch
```

### Secrets

```yaml
# opensearch-secrets.yaml
apiVersion: v1
kind: Secret
metadata:
  name: opensearch-credentials
  namespace: opensearch
type: Opaque
data:
  # Base64 encoded values (echo -n "admin" | base64)
  username: YWRtaW4=
  password: YWRtaW4=
  # Security config
  internal-users.yml: |-
    _meta:
      type: "internalusers"
      config_version: 2
    admin:
      hash: "$2y$12$..."  # Generated hash for your password
      reserved: true
      backend_roles:
      - "admin"
      description: "Admin user"
```

### ConfigMap

```yaml
# opensearch-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: opensearch-config
  namespace: opensearch
data:
  opensearch.yml: |-
    cluster.name: opensearch-cluster
    network.host: 0.0.0.0

    # Security settings
    plugins.security.ssl.transport.pemcert_filepath: esnode.pem
    plugins.security.ssl.transport.pemkey_filepath: esnode-key.pem
    plugins.security.ssl.transport.pemtrustedcas_filepath: root-ca.pem
    plugins.security.ssl.http.pemcert_filepath: esnode.pem
    plugins.security.ssl.http.pemkey_filepath: esnode-key.pem
    plugins.security.ssl.http.pemtrustedcas_filepath: root-ca.pem
    plugins.security.allow_unsafe_democertificates: true
    plugins.security.allow_default_init_securityindex: true
    plugins.security.authcz.admin_dn:
      - CN=kirk,OU=client,O=client,L=test,C=de

    # Node roles
    node.master: ${NODE_MASTER}
    node.data: ${NODE_DATA}
    node.ingest: ${NODE_INGEST}
    
    # Resource limits
    bootstrap.memory_lock: true
    
    # Path settings
    path.data: /usr/share/opensearch/data
    path.logs: /usr/share/opensearch/logs
    
    # Discovery settings
    discovery.seed_hosts: ["opensearch-cluster-master-headless"]
    cluster.initial_master_nodes: ["opensearch-cluster-master-0", "opensearch-cluster-master-1", "opensearch-cluster-master-2"]
    
    # Custom JVM settings
    opensearch.performance.analyzer.enabled: true
    
    # Advanced settings
    action.auto_create_index: ".security*,.opendistro*,.opensearch*,*"
    
  jvm.options: |-
    -Xms${JVM_HEAP_SIZE}
    -Xmx${JVM_HEAP_SIZE}
    -XX:+UseG1GC
    -XX:G1ReservePercent=25
    -XX:InitiatingHeapOccupancyPercent=30
    -XX:+HeapDumpOnOutOfMemoryError
    -XX:HeapDumpPath=/usr/share/opensearch/logs/
    -XX:ErrorFile=/usr/share/opensearch/logs/hs_err_pid%p.log
    -XX:+PrintGCDetails
    -XX:+PrintGCDateStamps
    -XX:+PrintTenuringDistribution
    -XX:+PrintGCApplicationStoppedTime
    -Xloggc:/usr/share/opensearch/logs/gc.log
    -XX:+UseGCLogFileRotation
    -XX:NumberOfGCLogFiles=32
    -XX:GCLogFileSize=64m
```

### Service

```yaml
# opensearch-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: opensearch-cluster
  namespace: opensearch
  labels:
    app: opensearch
spec:
  selector:
    app: opensearch
  ports:
  - name: http
    port: 9200
    targetPort: 9200
  - name: transport
    port: 9300
    targetPort: 9300
---
# Headless service for master nodes discovery
apiVersion: v1
kind: Service
metadata:
  name: opensearch-cluster-master-headless
  namespace: opensearch
  labels:
    app: opensearch
    role: master
spec:
  selector:
    app: opensearch
    role: master
  clusterIP: None
  ports:
  - name: transport
    port: 9300
    targetPort: 9300
```

### StatefulSet

```yaml
# opensearch-master-statefulset.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: opensearch-cluster-master
  namespace: opensearch
spec:
  serviceName: opensearch-cluster-master-headless
  replicas: 3
  selector:
    matchLabels:
      app: opensearch
      role: master
  template:
    metadata:
      labels:
        app: opensearch
        role: master
    spec:
      securityContext:
        fsGroup: 1000
      initContainers:
      - name: increase-vm-max-map-count
        image: busybox
        command: ["sysctl", "-w", "vm.max_map_count=262144"]
        securityContext:
          privileged: true
      - name: fix-permissions
        image: busybox
        command: ["sh", "-c", "chown -R 1000:1000 /usr/share/opensearch/data"]
        securityContext:
          privileged: true
        volumeMounts:
        - name: data
          mountPath: /usr/share/opensearch/data
      containers:
      - name: opensearch
        image: opensearchproject/opensearch:2.9.0
        env:
        - name: cluster.name
          value: opensearch-cluster
        - name: node.name
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: discovery.seed_hosts
          value: "opensearch-cluster-master-headless"
        - name: cluster.initial_master_nodes
          value: "opensearch-cluster-master-0,opensearch-cluster-master-1,opensearch-cluster-master-2"
        - name: NODE_MASTER
          value: "true"
        - name: NODE_DATA
          value: "false"
        - name: NODE_INGEST
          value: "false"
        - name: JVM_HEAP_SIZE
          value: "4g"
        - name: OPENSEARCH_JAVA_OPTS
          value: "-Xms4g -Xmx4g"
        - name: network.host
          value: "0.0.0.0"
        resources:
          limits:
            cpu: 2
            memory: 8Gi
          requests:
            cpu: 1
            memory: 4Gi
        ports:
        - containerPort: 9200
          name: http
        - containerPort: 9300
          name: transport
        volumeMounts:
        - name: data
          mountPath: /usr/share/opensearch/data
        - name: config
          mountPath: /usr/share/opensearch/config/opensearch.yml
          subPath: opensearch.yml
        - name: config
          mountPath: /usr/share/opensearch/config/jvm.options
          subPath: jvm.options
      volumes:
      - name: config
        configMap:
          name: opensearch-config
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: [ "ReadWriteOnce" ]
      storageClassName: opensearch-storage
      resources:
        requests:
          storage: 100Gi
```

```yaml
# opensearch-data-statefulset.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: opensearch-cluster-data
  namespace: opensearch
spec:
  serviceName: opensearch-cluster-data
  replicas: 3
  selector:
    matchLabels:
      app: opensearch
      role: data
  template:
    metadata:
      labels:
        app: opensearch
        role: data
    spec:
      securityContext:
        fsGroup: 1000
      initContainers:
      - name: increase-vm-max-map-count
        image: busybox
        command: ["sysctl", "-w", "vm.max_map_count=262144"]
        securityContext:
          privileged: true
      - name: fix-permissions
        image: busybox
        command: ["sh", "-c", "chown -R 1000:1000 /usr/share/opensearch/data"]
        securityContext:
          privileged: true
        volumeMounts:
        - name: data
          mountPath: /usr/share/opensearch/data
      containers:
      - name: opensearch
        image: opensearchproject/opensearch:2.9.0
        env:
        - name: cluster.name
          value: opensearch-cluster
        - name: node.name
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: discovery.seed_hosts
          value: "opensearch-cluster-master-headless"
        - name: NODE_MASTER
          value: "false"
        - name: NODE_DATA
          value: "true"
        - name: NODE_INGEST
          value: "false"
        - name: JVM_HEAP_SIZE
          value: "8g"
        - name: OPENSEARCH_JAVA_OPTS
          value: "-Xms8g -Xmx8g"
        resources:
          limits:
            cpu: 4
            memory: 16Gi
          requests:
            cpu: 2
            memory: 8Gi
        ports:
        - containerPort: 9200
          name: http
        - containerPort: 9300
          name: transport
        volumeMounts:
        - name: data
          mountPath: /usr/share/opensearch/data
        - name: config
          mountPath: /usr/share/opensearch/config/opensearch.yml
          subPath: opensearch.yml
        - name: config
          mountPath: /usr/share/opensearch/config/jvm.options
          subPath: jvm.options
      volumes:
      - name: config
        configMap:
          name: opensearch-config
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: [ "ReadWriteOnce" ]
      storageClassName: opensearch-storage
      resources:
        requests:
          storage: 500Gi
```

```yaml
# opensearch-client-statefulset.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: opensearch-cluster-client
  namespace: opensearch
spec:
  serviceName: opensearch-cluster-client
  replicas: 2
  selector:
    matchLabels:
      app: opensearch
      role: client
  template:
    metadata:
      labels:
        app: opensearch
        role: client
    spec:
      securityContext:
        fsGroup: 1000
      initContainers:
      - name: increase-vm-max-map-count
        image: busybox
        command: ["sysctl", "-w", "vm.max_map_count=262144"]
        securityContext:
          privileged: true
      containers:
      - name: opensearch
        image: opensearchproject/opensearch:2.9.0
        env:
        - name: cluster.name
          value: opensearch-cluster
        - name: node.name
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: discovery.seed_hosts
          value: "opensearch-cluster-master-headless"
        - name: NODE_MASTER
          value: "false"
        - name: NODE_DATA
          value: "false"
        - name: NODE_INGEST
          value: "true"
        - name: JVM_HEAP_SIZE
          value: "2g"
        - name: OPENSEARCH_JAVA_OPTS
          value: "-Xms2g -Xmx2g"
        resources:
          limits:
            cpu: 2
            memory: 4Gi
          requests:
            cpu: 1
            memory: 2Gi
        ports:
        - containerPort: 9200
          name: http
        - containerPort: 9300
          name: transport
        volumeMounts:
        - name: config
          mountPath: /usr/share/opensearch/config/opensearch.yml
          subPath: opensearch.yml
        - name: config
          mountPath: /usr/share/opensearch/config/jvm.options
          subPath: jvm.options
      volumes:
      - name: config
        configMap:
          name: opensearch-config
```

### Ingress

```yaml
# opensearch-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: opensearch-ingress
  namespace: opensearch
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
spec:
  tls:
  - hosts:
    - opensearch.example.com
    secretName: opensearch-tls-secret
  rules:
  - host: opensearch.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: opensearch-cluster
            port:
              name: http
```

### OpenSearch Dashboard

```yaml
# opensearch-dashboard-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: opensearch-dashboard
  namespace: opensearch
  labels:
    app: opensearch-dashboard
spec:
  replicas: 1
  selector:
    matchLabels:
      app: opensearch-dashboard
  template:
    metadata:
      labels:
        app: opensearch-dashboard
    spec:
      containers:
      - name: opensearch-dashboard
        image: opensearchproject/opensearch-dashboards:2.9.0
        ports:
        - containerPort: 5601
          name: web
        env:
        - name: OPENSEARCH_HOSTS
          value: https://opensearch-cluster:9200
        - name: SERVER_HOST
          value: "0.0.0.0"
        - name: SERVER_PORT
          value: "5601"
        - name: OPENSEARCH_USERNAME
          valueFrom:
            secretKeyRef:
              name: opensearch-credentials
              key: username
        - name: OPENSEARCH_PASSWORD
          valueFrom:
            secretKeyRef:
              name: opensearch-credentials
              key: password
        - name: OPENSEARCH_SSL_VERIFICATIONMODE
          value: none
        resources:
          limits:
            cpu: 1
            memory: 2Gi
          requests:
            cpu: 500m
            memory: 1Gi
---
apiVersion: v1
kind: Service
metadata:
  name: opensearch-dashboard
  namespace: opensearch
  labels:
    app: opensearch-dashboard
spec:
  selector:
    app: opensearch-dashboard
  ports:
  - name: http
    port: 5601
    targetPort: 5601
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: opensearch-dashboard-ingress
  namespace: opensearch
  annotations:
    kubernetes.io/ingress.class: nginx
spec:
  tls:
  - hosts:
    - dashboard.opensearch.example.com
    secretName: opensearch-dashboard-tls-secret
  rules:
  - host: dashboard.opensearch.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: opensearch-dashboard
            port:
              name: http
```

## Kustomization Files

### Base Kustomization

```yaml
# base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- namespace.yaml
- storageclass.yaml
- configmap.yaml
- secrets.yaml
- services/
- statefulsets/
- dashboard/

labels:
  app.kubernetes.io/name: opensearch
  app.kubernetes.io/part-of: opensearch-cluster
```

### Services Kustomization

```yaml
# base/services/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- cluster-service.yaml
- headless-service.yaml
```

### StatefulSets Kustomization

```yaml
# base/statefulsets/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- master-statefulset.yaml
- data-statefulset.yaml
- client-statefulset.yaml
```

### Dashboard Kustomization

```yaml
# base/dashboard/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- deployment.yaml
- service.yaml
```

### Development Overlay

```yaml
# overlays/development/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- ../../base

patches:
- resource-patch.yaml
- replicas-patch.yaml

namespace: opensearch-dev

labels:
  environment: development
```

### Production Overlay

```yaml
# overlays/production/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- ../../base
- ingress.yaml

patches:
- resource-patch.yaml
- replicas-patch.yaml

namespace: opensearch-prod

labels:
  environment: production
```

## Development Resource Patch

```yaml
# overlays/development/resource-patch.yaml
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
            cpu: 1
            memory: 2Gi
          requests:
            cpu: 500m
            memory: 1Gi
        env:
        - name: JVM_HEAP_SIZE
          value: "1g"
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: opensearch-cluster-data
spec:
  template:
    spec:
      containers:
      - name: opensearch
        resources:
          limits:
            cpu: 2
            memory: 4Gi
          requests:
            cpu: 1
            memory: 2Gi
        env:
        - name: JVM_HEAP_SIZE
          value: "2g"
```

## Development Replicas Patch

```yaml
# overlays/development/replicas-patch.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: opensearch-cluster-master
spec:
  replicas: 1
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: opensearch-cluster-data
spec:
  replicas: 1
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: opensearch-cluster-client
spec:
  replicas: 1
```

## Production Resource Patch

```yaml
# overlays/production/resource-patch.yaml
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
            cpu: 4
            memory: 16Gi
          requests:
            cpu: 2
            memory: 8Gi
        env:
        - name: JVM_HEAP_SIZE
          value: "8g"
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: opensearch-cluster-data
spec:
  template:
    spec:
      containers:
      - name: opensearch
        resources:
          limits:
            cpu: 8
            memory: 32Gi
          requests:
            cpu: 4
            memory: 16Gi
        env:
        - name: JVM_HEAP_SIZE
          value: "16g"
```

## Production Replicas Patch

```yaml
# overlays/production/replicas-patch.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: opensearch-cluster-master
spec:
  replicas: 3
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: opensearch-cluster-data
spec:
  replicas: 5
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: opensearch-cluster-client
spec:
  replicas: 3
```

## Deployment Instructions

1. Choose your deployment environment:

   For development environment:
   ```bash
   kubectl apply -k opensearch-k8s/overlays/development
   ```

   For production environment:
   ```bash
   kubectl apply -k opensearch-k8s/overlays/production
   ```

2. Wait for master nodes to be ready:
   ```bash
   kubectl wait --for=condition=Ready pod/opensearch-cluster-master-0 -n opensearch-prod --timeout=300s
   ```

3. Verify the deployment:
   ```bash
   kubectl get pods -n opensearch-prod
   kubectl get services -n opensearch-prod
   ```

## Customization Options

You can customize the following parameters:

### Cluster Size
- Adjust `replicas` in the StatefulSet definitions
- Scale data nodes based on your storage needs
- Scale client nodes based on your query load

### Resource Allocation
- Change CPU and memory `requests` and `limits` in StatefulSets
- Adjust `JVM_HEAP_SIZE` for each node type

### Storage
- Modify `storage` requests in `volumeClaimTemplates`
- Change `storageClassName` to match your environment

### Network Configuration
- Update `discovery.seed_hosts` and `cluster.initial_master_nodes` for larger clusters
- Modify service definitions for custom networking requirements

### Security
- Update security settings in the ConfigMap
- Configure custom TLS certificates
- Set up proper authentication in secrets

### OpenSearch Configuration
- Add plugins by customizing the container image
- Tune OpenSearch settings in the ConfigMap
- Add custom analyzers, mappings, and templates

### Monitoring
- Add Prometheus monitoring through annotations
- Set up logging with Fluentd or Filebeat
