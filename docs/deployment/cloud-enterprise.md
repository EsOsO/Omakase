# Cloud Enterprise Deployment

Deploy Omakase on enterprise cloud platforms with Kubernetes for production-grade infrastructure.

## Overview

**Enterprise cloud deployment** provides scalable, highly-available infrastructure using managed Kubernetes services.

**Advantages**:
- High availability
- Auto-scaling
- Multi-region deployment
- Enterprise SLA
- Managed services
- Professional support

**Disadvantages**:
- Higher complexity
- Significantly higher cost
- Requires Kubernetes knowledge
- Overkill for personal homelab

**Note**: This deployment method is for **organizations** needing production-grade infrastructure, not typical homelab users.

## When to Use

Consider enterprise deployment when:
- Multiple users/teams
- Business-critical services
- Compliance requirements (SOC2, HIPAA, etc.)
- Need for 99.9%+ uptime
- Multi-region requirements
- Large scale (100+ users)

## Cloud Providers

### Amazon EKS (AWS)

**Advantages**:
- Mature ecosystem
- Wide service catalog
- Global presence

**Cost**: ~$300-500/month (small cluster)

### Google GKE (GCP)

**Advantages**:
- Best Kubernetes experience
- Excellent networking
- Autopilot mode

**Cost**: ~$250-400/month (small cluster)

### Azure AKS

**Advantages**:
- Microsoft integration
- Hybrid cloud options
- Enterprise features

**Cost**: ~$300-450/month (small cluster)

### DigitalOcean Kubernetes

**Advantages**:
- Simplest setup
- Lower cost
- Good for startups

**Cost**: ~$120-200/month (small cluster)

## Architecture

### Kubernetes Cluster

**Control Plane**: Managed by provider
**Worker Nodes**: 3-5 nodes for HA

**Node specifications**:
- 4 vCPU, 16GB RAM per node
- 100GB SSD per node
- Auto-scaling enabled

### Storage

**Persistent Volumes**:
- Use provider's block storage (EBS, Persistent Disk, etc.)
- StorageClass with encryption
- Automated backups

**Object Storage**:
- S3, GCS, or Azure Blob
- For media and backups

### Networking

**Load Balancer**: Cloud provider load balancer
**Ingress Controller**: Nginx Ingress or Traefik
**Service Mesh** (optional): Istio or Linkerd

## Conversion to Kubernetes

Omakase is Docker Compose-based. For Kubernetes deployment:

### Option 1: Kompose

Convert Docker Compose to Kubernetes manifests:

```bash
# Install kompose
curl -L https://github.com/kubernetes/kompose/releases/download/v1.31.2/kompose-linux-amd64 -o kompose
chmod +x kompose
sudo mv kompose /usr/local/bin/

# Convert
cd omakase
kompose convert -f compose.yaml -f compose.prod.yaml
```

Manually adjust generated manifests.

### Option 2: Helm Chart

Create Helm chart for Omakase:

```yaml
# Chart.yaml
apiVersion: v2
name: omakase
version: 1.0.0
description: Omakase Homelab Infrastructure

# values.yaml
replicaCount: 3

image:
  traefik:
    repository: traefik
    tag: v3.0

  authelia:
    repository: authelia/authelia
    tag: latest

persistence:
  enabled: true
  storageClass: gp3
  size: 100Gi

ingress:
  enabled: true
  className: nginx
  hosts:
    - host: "*.yourdomain.com"
```

### Option 3: Keep Docker Compose

Run Docker Compose on Kubernetes using:
- **Docker Compose on Kubernetes**: Not recommended
- **Podman with Kubernetes**: Alternative approach

## Deployment Steps

### 1. Create Kubernetes Cluster

**AWS EKS**:
```bash
eksctl create cluster \
  --name omakase \
  --region us-east-1 \
  --nodegroup-name standard-workers \
  --node-type t3.xlarge \
  --nodes 3 \
  --nodes-min 3 \
  --nodes-max 10 \
  --managed
```

**GKE**:
```bash
gcloud container clusters create omakase \
  --zone us-central1-a \
  --num-nodes 3 \
  --machine-type n1-standard-4 \
  --enable-autoscaling \
  --min-nodes 3 \
  --max-nodes 10
```

**AKS**:
```bash
az aks create \
  --resource-group omakase-rg \
  --name omakase \
  --node-count 3 \
  --node-vm-size Standard_D4s_v3 \
  --enable-cluster-autoscaler \
  --min-count 3 \
  --max-count 10
```

### 2. Install Ingress Controller

**Nginx Ingress**:
```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --set controller.service.type=LoadBalancer
```

### 3. Install Cert-Manager

For automatic SSL certificates:
```bash
helm repo add jetstack https://charts.jetstack.io
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set installCRDs=true
```

### 4. Deploy Services

Apply Kubernetes manifests:
```bash
kubectl create namespace omakase
kubectl apply -f k8s/traefik/
kubectl apply -f k8s/authelia/
kubectl apply -f k8s/services/
```

### 5. Configure DNS

Point domain to LoadBalancer IP:
```bash
kubectl get service ingress-nginx-controller -o wide
```

Update DNS A records to LoadBalancer IP.

## High Availability

### Pod Replication

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: traefik
spec:
  replicas: 3  # Multiple replicas
  selector:
    matchLabels:
      app: traefik
```

### Pod Disruption Budget

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: traefik-pdb
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: traefik
```

### Multi-AZ Deployment

Ensure nodes span multiple availability zones.

### Database HA

Use managed database services:
- AWS RDS
- Google Cloud SQL
- Azure Database

With multi-AZ deployment and read replicas.

## Storage

### StatefulSets

For services needing persistent storage:

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: nextcloud
spec:
  serviceName: nextcloud
  replicas: 1
  volumeClaimTemplates:
    - metadata:
        name: data
      spec:
        accessModes: ["ReadWriteOnce"]
        storageClassName: gp3
        resources:
          requests:
            storage: 100Gi
```

### Storage Classes

Define storage classes:

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
provisioner: kubernetes.io/aws-ebs
parameters:
  type: gp3
  iops: "3000"
  throughput: "125"
  encrypted: "true"
```

## Secrets Management

### External Secrets Operator

Integrate with cloud secret managers:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: aws-secrets-manager
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-east-1
```

### Sealed Secrets

Encrypt secrets in git:

```bash
kubeseal --format=yaml < secret.yaml > sealed-secret.yaml
kubectl apply -f sealed-secret.yaml
```

## Monitoring

### Prometheus + Grafana

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace
```

### Cloud Provider Monitoring

Use native monitoring:
- AWS CloudWatch
- Google Cloud Monitoring
- Azure Monitor

## Cost Management

### Auto-Scaling

**Horizontal Pod Autoscaler**:
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: traefik-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: traefik
  minReplicas: 2
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
```

**Cluster Autoscaler**: Automatically adjust node count.

### Spot Instances

Use spot/preemptible instances for non-critical workloads:
- Save 60-90% on compute costs
- Acceptable for stateless services

### Resource Limits

Set resource requests/limits:

```yaml
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi
```

### Cost Monitoring

- Enable cloud cost explorer
- Set budget alerts
- Use tools like Kubecost

## Security

### Network Policies

Restrict pod-to-pod communication:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-ingress
spec:
  podSelector: {}
  policyTypes:
    - Ingress
```

### Pod Security Standards

Enforce security policies:

```yaml
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: restricted
spec:
  privileged: false
  allowPrivilegeEscalation: false
  runAsUser:
    rule: MustRunAsNonRoot
```

### RBAC

Implement role-based access control.

### Image Scanning

Use tools like:
- Trivy
- Snyk
- Aqua Security

## Disaster Recovery

### Backup

**Velero**: Kubernetes backup tool

```bash
velero install \
  --provider aws \
  --plugins velero/velero-plugin-for-aws:v1.8.0 \
  --bucket omakase-backups \
  --backup-location-config region=us-east-1

# Create backup
velero backup create omakase-backup
```

### Multi-Region

Deploy to multiple regions for DR:
- Active-passive: Standby cluster in another region
- Active-active: Both regions serve traffic

## CI/CD

### GitOps with ArgoCD

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

Configure ArgoCD to sync from git repository.

### Automated Deployments

Use GitHub Actions or GitLab CI:

```yaml
name: Deploy to EKS
on:
  push:
    branches: [main]
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: aws-actions/configure-aws-credentials@v2
      - run: kubectl apply -f k8s/
```

## Estimated Costs

### Small Deployment

- **Cluster**: $150-200/month
- **Compute**: 3 nodes × $50 = $150/month
- **Storage**: 500GB × $0.10 = $50/month
- **Load Balancer**: $20/month
- **Transfer**: $20-50/month

**Total**: ~$390-470/month

### Medium Deployment

- **Cluster**: $150-200/month
- **Compute**: 5 nodes × $100 = $500/month
- **Storage**: 2TB × $0.10 = $200/month
- **Load Balancer**: $40/month
- **Transfer**: $100-200/month

**Total**: ~$990-1240/month

## Alternatives

For most homelab users, enterprise Kubernetes is overkill. Consider:
- [Bare Metal](bare-metal.md) - Best performance
- [VM Deployment](vm-generic.md) - Good flexibility
- [Cloud VPS](cloud-vps.md) - Simple cloud option

## See Also

- [Cloud VPS Deployment](cloud-vps.md) - Simpler cloud option
- [Installation Guide](../getting-started/installation.md)
- [Security Best Practices](../security/best-practices.md)
