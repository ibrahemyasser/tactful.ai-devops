# Voting Application - Production-Ready Cloud Infrastructure

A fully automated, secure, and scalable microservices-based voting application deployed on AWS EKS with comprehensive CI/CD pipelines, infrastructure as code, and enterprise-grade security practices.

## 📋 Table of Contents

- [Architecture Overview](#architecture-overview)
- [Prerequisites](#prerequisites)
- [Local Development Setup](#local-development-setup)
- [AWS Cloud Deployment](#aws-cloud-deployment)
- [CI/CD Pipeline](#cicd-pipeline)
- [Security Features](#security-features)
- [Design Decisions & Trade-offs](#design-decisions--trade-offs)
- [Monitoring & Observability](#monitoring--observability)
- [Troubleshooting](#troubleshooting)

---

## 🏗️ Architecture Overview

### Application Components

The voting application consists of five microservices:

1. **Vote Service** (Python/Flask)
   - Frontend for casting votes (Cats vs Dogs)
   - Stores votes in Redis queue
   - Exposed on port 80

2. **Result Service** (Node.js/Express + Socket.IO)
   - Real-time results dashboard
   - Queries PostgreSQL for vote counts
   - WebSocket-based live updates
   - Exposed on port 8081

3. **Worker Service** (C#/.NET)
   - Background processor
   - Consumes votes from Redis
   - Persists to PostgreSQL
   - Creates `votes` table on startup

4. **PostgreSQL** (Database)
   - Persistent vote storage
   - Deployed via Bitnami Helm chart
   - StatefulSet with PVC

5. **Redis** (Cache/Queue)
   - Temporary vote queue
   - Deployed via Bitnami Helm chart
   - StatefulSet with PVC

6. **Seed Service** (Optional)
   - Test data generator
   - Only runs with `--profile seed`

### Infrastructure Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         AWS Cloud (EKS)                          │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                   Application Load Balancer              │   │
│  │  ┌──────────────┐              ┌──────────────┐         │   │
│  │  │ Vote Ingress │              │Result Ingress│         │   │
│  │  └──────┬───────┘              └──────┬───────┘         │   │
│  └─────────┼──────────────────────────────┼────────────────┘   │
│            │                              │                     │
│  ┌─────────▼──────────────────────────────▼────────────────┐   │
│  │              Kubernetes Cluster (EKS)                    │   │
│  │                                                           │   │
│  │  ┌───────┐    ┌────────┐    ┌────────┐                 │   │
│  │  │ Vote  │───▶│ Redis  │◀───│ Worker │                 │   │
│  │  └───────┘    └────────┘    └───┬────┘                 │   │
│  │                                  │                       │   │
│  │  ┌────────┐                      │                      │   │
│  │  │ Result │──────────────────────▼                      │   │
│  │  └────────┘              ┌──────────────┐               │   │
│  │                          │  PostgreSQL  │               │   │
│  │                          └──────────────┘               │   │
│  │                                                          │   │
│  │  Network Policies: Backend isolation, DNS allow         │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ Infrastructure Components                                │   │
│  │ • VPC with 3 AZs (public + private subnets)             │   │
│  │ • NAT Gateways for private subnet internet access        │   │
│  │ • ALB Controller v2.16.0 for ingress                     │   │
│  │ • External Secrets Operator + AWS Secrets Manager        │   │
│  │ • EBS CSI Driver with Pod Identity                       │   │
│  │ • Bastion host in prod (SSM Session Manager)            │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

### Network Architecture

- **Two-Tier Networking** (Docker Compose):
  - **Frontend Tier**: Vote, Result (exposed to users)
  - **Backend Tier**: Worker, Redis, PostgreSQL (isolated)

- **Kubernetes Network Policies**:
  - Default deny all traffic
  - Explicit allow rules for service communication
  - DNS resolution permitted for all pods
  - PostgreSQL and Redis isolated to backend only

---

## 📦 Prerequisites

### Local Development
- Docker Engine 24.0+
- Docker Compose v2.20+
- Git

### AWS Cloud Deployment
- AWS CLI v2.13+
- Terraform 1.9+ / Terragrunt
- kubectl 1.30+
- Helm 3.15+
- jq (for JSON processing)
- AWS Account with:
  - EKS cluster creation permissions
  - VPC and networking permissions
  - IAM role creation permissions
  - Secrets Manager access

### GitHub Repository Setup
- GitHub repository with Actions enabled
- GitHub Secrets configured:
  - `AWS_ROLE_ARN`: OIDC role for GitHub Actions
  - `DOCKER_PASSWORD`: Docker Hub access token
- GitHub Variables:
  - `AWS_REGION`: Target AWS region (e.g., `us-east-1`)

---

## 🚀 Local Development Setup

### Quick Start with Docker Compose

1. **Clone the repository**
   ```bash
   git clone https://github.com/ibrahemyasser/tactful.ai-devops.git
   cd tactful.ai-devops
   ```

2. **Start all services**
   ```bash
   docker compose up --build
   ```

3. **Access the application**
   - Vote: http://localhost:8080
   - Result: http://localhost:8081

4. **Optional: Run with test data**
   ```bash
   docker compose --profile seed up --build
   ```

5. **Stop services**
   ```bash
   docker compose down -v  # -v removes volumes
   ```

### Docker Compose Features

- ✅ **Two-tier networking**: Frontend (vote, result) and Backend (worker, redis, postgres)
- ✅ **Health checks**: Redis and PostgreSQL have readiness checks
- ✅ **Automatic restarts**: All services restart unless manually stopped
- ✅ **Volume persistence**: PostgreSQL data persists across restarts
- ✅ **Dependency management**: Services wait for dependencies to be healthy
- ✅ **Resource isolation**: Each service runs in its own container

### Architecture Validation

```bash
# Check running services
docker compose ps

# View logs
docker compose logs -f

# Test connectivity
curl http://localhost:8080  # Vote page
curl http://localhost:8081  # Result page

# Check backend services
docker compose exec redis redis-cli ping  # Should return PONG
docker compose exec db psql -U postgres -c "\dt"  # List tables
```

---

## ☁️ AWS Cloud Deployment

### Infrastructure Setup with Terraform

The infrastructure is organized into reusable modules with separate environments (dev/prod).

#### Directory Structure

```
terraform-infrastructure/
├── root.hcl                 # Terragrunt root config
├── modules/
│   ├── vpc/                 # VPC, subnets, NAT gateways
│   ├── eks-cluster/         # EKS cluster, node groups, Pod Identity
│   ├── bastion/             # Prod bastion host (SSM)
│   └── secrets-manager/     # PostgreSQL password secret
└── environments/
    ├── dev/
    │   ├── vpc/
    │   ├── eks-cluster/
    │   ├── secrets-manager/
    │   └── github-oidc/
    └── prod/
        ├── vpc/
        ├── eks-cluster/
        ├── secrets-manager/
        ├── bastion/
        └── github-oidc/
```

#### Step 1: Configure GitHub OIDC Provider

This enables GitHub Actions to assume AWS roles without storing credentials.

```bash
cd terraform-infrastructure/environments/dev/github-oidc

# Initialize and apply
terragrunt init
terragrunt apply
```

**Output**: Copy the `github_actions_role_arn` to GitHub Secrets as `AWS_ROLE_ARN`

#### Step 2: Create Secrets Manager Secret

```bash
cd ../secrets-manager
terragrunt apply
```

**Output**: Secret ARN for PostgreSQL password (auto-generated secure password)

#### Step 3: Deploy VPC

```bash
cd ../vpc
terragrunt apply
```

**Created Resources**:
- VPC with CIDR 10.0.0.0/16
- 3 public subnets (10.0.1.0/24, 10.0.2.0/24, 10.0.3.0/24)
- 3 private subnets (10.0.11.0/24, 10.0.12.0/24, 10.0.13.0/24)
- Internet Gateway
- 3 NAT Gateways (one per AZ for high availability)
- Route tables
- VPC Endpoints for SSM (Session Manager)

#### Step 4: Deploy EKS Cluster

```bash
cd ../eks-cluster
terragrunt apply
```

**Created Resources**:
- EKS 1.34 cluster with public endpoint (dev) / private (prod)
- Node group:
  - **General**: m7i-flex.large, 2-4 nodes (all workloads)
- Pod Identity Agent addon
- EBS CSI Driver addon with Pod Identity
- CloudWatch logging enabled (all control plane logs)
- Encryption at rest with KMS

**Configuration**: `~/.kube/config` is automatically updated

#### Step 5: Repeat for Production

```bash
cd ../../prod/github-oidc && terragrunt apply
cd ../secrets-manager && terragrunt apply
cd ../vpc && terragrunt apply
cd ../bastion && terragrunt apply  # Production includes bastion
cd ../eks-cluster && terragrunt apply
```

**Production Differences**:
- Private endpoint only
- Bastion host for secure access via SSM Session Manager
- Larger node instance types (can be configured)
- Additional node groups for isolation

### Manual Infrastructure Deployment (via GitHub Actions)

Alternatively, use the GitHub Actions workflow:

1. Go to **Actions** → **CD - Deploy Infrastructure**
2. Click **Run workflow**
3. Select environment: `dev` or `prod`
4. Choose module: `all`, `vpc`, `eks-cluster`, `secrets-manager`, or `bastion`
5. Action: `plan` (review) or `apply` (deploy)

### Kubernetes Cluster Setup

After EKS cluster is created, install required components:

```bash
# Option 1: Automated via GitHub Actions
# Go to Actions → CD - Setup EKS Cluster → Run workflow → Select environment

# Option 2: Manual setup
cd tactful.ai-devops

# Update kubeconfig
aws eks update-kubeconfig --name tactful-voting-dev --region us-east-1

# Install External Secrets Operator
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets -n external-secrets-system --create-namespace

# Install AWS Load Balancer Controller
helm repo add eks https://aws.github.io/eks-charts
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=tactful-voting-dev \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller

# Deploy infrastructure Helm chart (namespace, ServiceAccount, SecretStore)
helm install infrastructure helm-chart/infrastructure -n voting-dev --create-namespace

# Deploy PostgreSQL
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install postgresql bitnami/postgresql \
  -n voting-dev \
  -f helm-chart/postgresql/values.yaml \
  -f helm-chart/postgresql/values-dev.yaml

# Deploy Redis
helm install redis bitnami/redis \
  -n voting-dev \
  -f helm-chart/redis/values.yaml \
  -f helm-chart/redis/values-dev.yaml
```

### Application Deployment

```bash
# Deploy voting application
helm install voting-app helm-chart/vote-app \
  -n voting-dev \
  -f helm-chart/vote-app/values.yaml \
  -f helm-chart/vote-app/values-dev.yaml

# Get ingress URLs
kubectl get ingress -n voting-dev

# Output:
# vote-ingress    alb    k8s-votingde-voteingr-xxx.elb.amazonaws.com
# result-ingress  alb    k8s-votingde-resultin-xxx.elb.amazonaws.com
```

---

## 🔄 CI/CD Pipeline

### Pipeline Architecture

```
┌──────────────┐    ┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│  Code Push   │───▶│   CI Build   │───▶│   CD Deploy  │───▶│ Smoke Tests  │
│  (main)      │    │   & Scan     │    │   (Auto)     │    │              │
└──────────────┘    └──────────────┘    └──────────────┘    └──────────────┘
```

### CI Workflow: Build and Push Images

**Trigger**: Push to `main` branch with changes in `vote/`, `result/`, or `worker/`

**File**: `.github/workflows/ci-build-images.yaml`

**Steps**:
1. **Detect Changes**: Uses path filter to identify modified services
2. **Build Image**: Docker Buildx with layer caching
3. **Security Scan**: Trivy scans for CRITICAL and HIGH vulnerabilities
4. **Upload Results**: SARIF report to GitHub Security tab
5. **Push Images**: Only if scan passes
   - Tags: `sha-<commit>` and `latest`
   - Registry: Docker Hub (`ibrahim1025/vote`, `ibrahim1025/result`, `ibrahim1025/worker`)

**Security Features**:
- ✅ Non-root Dockerfiles
- ✅ Multi-stage builds (minimal attack surface)
- ✅ Vulnerability scanning before push
- ✅ No credentials in code (GitHub Secrets)

### CD Workflow: Deploy Application

**Triggers**:
1. **Automatic**: After successful CI build (dev only)
2. **Manual**: Workflow dispatch (dev or prod)
3. **Helm Changes**: Push to Helm chart files

**File**: `.github/workflows/cd-deploy-app.yaml`

**Dev Environment** (Automatic):
1. **Cluster Readiness Check**: Verify namespace and data stores exist
2. **Tag Resolution**: 
   - For CI trigger: Use newly built SHA tags
   - For Helm changes: Resolve `latest` to actual SHA for traceability
   - Per-service logic: Only update changed services
3. **Helm Upgrade**: Rolling deployment with zero downtime
4. **Smoke Tests**: Verify ingress endpoints return expected content

**Prod Environment** (Manual Only):
1. Requires manual approval (environment protection rule)
2. Deploys via SSM Session Manager to bastion host
3. Rollback on failure
4. Smoke tests after successful deployment

**Image Tag Strategy**:
- `values.yaml` uses `latest` for simplicity
- CD workflow resolves `latest` to SHA tags for audit trail
- Per-service detection: Only services with new images get updated
- Traceability: Deployment summary shows exact SHA deployed

### Infrastructure Workflow: Terraform Automation

**File**: `.github/workflows/cd-deploy-infra.yaml`

**Trigger**: Manual only (infrastructure changes require review)

**Capabilities**:
- Plan or apply Terraform changes
- Select environment (dev/prod)
- Select module (vpc, eks-cluster, secrets-manager, bastion, or all)
- Automatic cluster setup after EKS creation

**Safety Features**:
- Manual trigger only (no auto-deploy)
- Terraform state in S3 backend
- Plan always runs before apply
- Environment-specific isolation

### Smoke Tests

**File**: `.github/workflows/smoke-tests.yaml`

**Tests**:
1. Vote ingress returns page with "cats" or "dogs"
2. Result ingress returns page with "result" or "votes"
3. Both endpoints return HTTP 200

**Environments**:
- **Dev**: Direct kubectl access from GitHub Actions runner
- **Prod**: SSM commands via bastion host

---

## 🔒 Security Features

### Container Security

#### Non-Root Containers
All application containers run as non-root users (UID 1000):

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 1000
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: false  # Apps need /tmp write access
  capabilities:
    drop: ["ALL"]
```

#### Dockerfile Best Practices
- Single-stage builds with minimal base images
- Install dependencies as root, then switch to non-root
- Explicit user creation (UID 1000) and ownership changes
- No sensitive data in layers

**Example** (`vote/Dockerfile`):
```dockerfile
FROM python:3.11-slim
WORKDIR /app

# Install dependencies as root
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application files
COPY . .

# Create non-root user and change ownership
RUN useradd -m -u 1000 appuser && \
    chown -R appuser:appuser /app

USER appuser
EXPOSE 8080
CMD ["gunicorn", "app:app", "-b", "0.0.0.0:80", "--log-file", "-", "--access-logfile", "-", "--workers", "4", "--keep-alive", "0"]
```

### Kubernetes Security

#### Pod Security Admission (PSA)
Namespace enforcement level: **Restricted** (strictest security policy)

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: voting-dev
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

**Restricted Policy Requirements**:
- All containers must run as non-root
- No privilege escalation allowed
- All capabilities dropped
- Read-only root filesystem (or explicitly allow writable)
- seccompProfile must be set

#### Network Policies
Implements **zero-trust networking**:

1. **Default Deny All**:
   ```yaml
   apiVersion: networking.k8s.io/v1
   kind: NetworkPolicy
   metadata:
     name: default-deny
   spec:
     podSelector: {}
     policyTypes: ["Ingress", "Egress"]
   ```

2. **Allow DNS** (all pods need DNS resolution):
   ```yaml
   egress:
   - to:
     - namespaceSelector:
         matchLabels:
           name: kube-system
     ports:
     - protocol: UDP
       port: 53
   ```

3. **Service-Specific Rules**:
   - Vote → Redis (port 6379)
   - Worker → Redis (port 6379) + PostgreSQL (port 5432)
   - Result → PostgreSQL (port 5432)
   - PostgreSQL/Redis → Isolated to backend only

#### RBAC (Role-Based Access Control)

**ServiceAccount**: `voting-app-sa` with minimal permissions

**Pod Identity**: Used for AWS service access (EBS CSI, External Secrets)
- No IAM credentials in pods
- IAM roles assigned via Pod Identity associations
- Scoped permissions per service account

#### Secrets Management

**AWS Secrets Manager** with **External Secrets Operator**:

1. PostgreSQL password stored in Secrets Manager
2. External Secrets syncs to Kubernetes Secret
3. Secret mounted as environment variables (not files for security)

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: postgresql-credentials
spec:
  secretStoreRef:
    name: aws-secretsmanager
    kind: SecretStore
  target:
    name: postgresql-credentials
  data:
    - secretKey: password
      remoteRef:
        key: tactful-voting-dev-postgresql
        property: password
```

**Benefits**:
- Secrets never in Git
- Automatic rotation support
- Centralized secret management
- Audit trail in AWS CloudTrail

### Vulnerability Scanning

**Trivy Integration** in CI pipeline:
- Scans for CVEs in base images and dependencies
- Blocks push if CRITICAL vulnerabilities found (configurable)
- Reports uploaded to GitHub Security tab
- Ignores unfixed vulnerabilities (no patch available)

```yaml
- uses: aquasecurity/trivy-action@master
  with:
    severity: 'CRITICAL,HIGH'
    exit-code: '0'  # Don't fail build, just report
    ignore-unfixed: true
```

### Network Security

**VPC Design**:
- Private subnets for EKS nodes (no direct internet)
- NAT Gateways for outbound internet (updates, Docker pulls)
- Security groups with least privilege
- VPC Flow Logs enabled (can be configured)

**ALB Security**:
- Internet-facing for dev (testing)
- Internal for prod (accessed via VPN/VPC peering)
- SSL/TLS termination at ALB (can add ACM certificates)
- Security groups restrict ingress to HTTP/HTTPS only

---

## 🎯 Design Decisions & Trade-offs

### 1. AWS EKS vs Azure AKS

**Why AWS Instead of Azure**:
- ✅ **Personal Expertise**: Deeper experience with AWS services
- ✅ **GitHub Actions Integration**: Native AWS OIDC support, no credential storage
- ✅ **Feature Parity**: EKS Pod Identity ≈ Azure Workload Identity
- ✅ **Cost Optimization**: Free tier eligibility, spot instances available
- ✅ **Ecosystem Maturity**: More Helm charts and operators tested on EKS

**Trade-offs Documented**:
- Migration path to Azure would require:
  - Replace `aws_*` Terraform resources with `azurerm_*`
  - Use Azure Workload Identity instead of Pod Identity
  - Use Azure Key Vault instead of Secrets Manager
  - Use Azure Container Registry instead of Docker Hub
  - Core Kubernetes/Helm components remain the same

**Equivalent Azure Services**:
| AWS Service | Azure Equivalent |
|-------------|------------------|
| EKS | AKS (Azure Kubernetes Service) |
| VPC | Virtual Network (VNet) |
| Security Groups | Network Security Groups (NSG) |
| ALB | Application Gateway + Ingress Controller |
| Secrets Manager | Key Vault |
| Pod Identity | Workload Identity |
| IAM Roles | Managed Identities |

### 2. Two Separate Ingresses vs Single Ingress

**Decision**: Use two separate ALB Ingresses (vote-ingress, result-ingress)

**Reasoning**:
- ✅ **Simplicity**: No path rewriting needed (apps at root `/`)
- ✅ **Isolation**: Independent ALB per service (failure isolation)
- ✅ **Flexibility**: Different security groups, SSL policies per ALB
- ✅ **Cost**: Minimal (~$16/month per ALB vs complexity cost)

**Alternative Considered**: Single ingress with path-based routing
- ❌ Requires Nginx sidecar for path rewriting
- ❌ Breaks static asset paths (CSS, JS)
- ❌ More complex troubleshooting

### 3. Bitnami Helm Charts vs Custom Manifests

**Decision**: Use Bitnami PostgreSQL and Redis Helm charts

**Reasoning**:
- ✅ **Production-Ready**: Battle-tested configurations
- ✅ **Best Practices**: Security contexts, probes, resource limits pre-configured
- ✅ **Maintenance**: Automatic security updates
- ✅ **Features**: Backup, monitoring, HA out-of-the-box

**Trade-offs**:
- ⚠️ Opinionated defaults (can override with values)
- ⚠️ More resources than minimal setup
- ⚠️ Learning curve for chart customization

**Plain Manifests Provided**: For learning/customization in `k8s-manifests/`

### 4. Automatic CD for Dev, Manual for Prod

**Decision**: Dev auto-deploys after CI, Prod requires manual trigger

**Reasoning**:
- ✅ **Velocity**: Fast feedback loop in dev (5-10 min code → deployed)
- ✅ **Safety**: Prod changes reviewed and approved
- ✅ **Testing**: Dev is integration environment before prod
- ✅ **Rollback**: Helm history allows easy rollback in both environments

**Workflow**:
```
Developer Push → CI Builds → Dev Auto-Deploy → Manual Prod Deploy
                    ↓
              Trivy Scan (security gate)
```

### 5. Image Tag Strategy: Latest in Values, SHA in Deployment

**Decision**: 
- `values.yaml` uses `latest` tag
- CD workflow resolves `latest` to SHA tags at deployment time

**Reasoning**:
- ✅ **Simplicity**: Developers don't update values.yaml for every commit
- ✅ **Traceability**: SHA tags in deployment logs (audit trail)
- ✅ **Flexibility**: Can override with manual workflow dispatch
- ✅ **No Drift**: Per-service detection prevents deploying stale images

**How It Works**:
1. CI builds `vote:sha-abc1234` and tags as `vote:latest`
2. `values.yaml` has `vote.image.tag: latest`
3. CD workflow queries Docker Hub: "What SHA does `latest` point to?"
4. CD deploys with `--set vote.image.tag=sha-abc1234`
5. Audit log shows exact SHA deployed

### 6. Pod Identity vs IRSA (IAM Roles for Service Accounts)

**Decision**: Use EKS Pod Identity instead of IRSA

**Reasoning**:
- ✅ **Simplicity**: Native EKS feature, no OIDC provider setup
- ✅ **Performance**: Faster credential retrieval
- ✅ **AWS Recommended**: EKS team's preferred method (2024+)
- ✅ **Consistency**: Same pattern as Azure Workload Identity

**Migration Note**: IRSA still supported, easy to switch if needed

### 7. Terragrunt for DRY Infrastructure

**Decision**: Use Terragrunt to avoid Terraform code duplication

**Reasoning**:
- ✅ **DRY**: Modules defined once, reused across environments
- ✅ **Consistency**: Same configuration structure for dev/prod
- ✅ **Safety**: Environment-specific variable files prevent accidents
- ✅ **Remote State**: Automatic S3 backend configuration

**File Structure**:
```
root.hcl (common config) → env.hcl (environment vars) → terragrunt.hcl (module)
```

### 8. High Availability Configuration

**Decisions**:
- **Topology Spread**: Pods distributed across availability zones (max skew: 1)
- **Rolling Updates**: Zero downtime (maxUnavailable: 0, maxSurge: 1)
- **Node Configuration**: Single general-purpose node group for simplicity

**Reasoning**:
- ✅ **Zone Failure Tolerance**: If AZ goes down, other zones serve traffic
- ✅ **Gradual Rollout**: New pods start before old ones terminate
- ✅ **Cost Efficiency**: Single node group reduces operational overhead for this workload size

**Cost Trade-off**: 
- Requires 2+ replicas per service
- More nodes to span zones
- ~30% higher compute cost for 99.9% availability

---

## 📊 Monitoring & Observability

### Current State

**Logging**:
- ✅ CloudWatch Logs for EKS control plane
- ✅ Container logs via `kubectl logs`
- ✅ Application-level logging (stdout/stderr)

**Metrics**:
- ✅ Kubernetes resource metrics (CPU, memory, pods)
- ✅ ALB access logs (can enable to S3)
- ✅ VPC Flow Logs (can enable)

### Future Enhancements

**Prometheus + Grafana Stack** (planned):
```bash
# Install kube-prometheus-stack
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace

# Access Grafana
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
# Default: admin / prom-operator
```

**ServiceMonitors** (to be added):
- Vote service metrics (request count, latency, errors)
- Result service metrics (WebSocket connections, query times)
- Worker service metrics (votes processed, queue depth)

**Key Dashboards**:
1. **Cluster Overview**: Node health, pod count, resource usage
2. **Application**: Request rates, error rates, latency (RED metrics)
3. **Data Stores**: PostgreSQL connections, Redis memory, query times
4. **Ingress**: ALB metrics, request volume, 5xx errors

---

## 🔧 Troubleshooting

### Common Issues

#### 1. Pods in ImagePullBackOff

**Symptom**: `kubectl get pods` shows `ImagePullBackOff`

**Causes**:
- Docker Hub rate limits (anonymous pulls limited to 100/6hr)
- Image doesn't exist (typo in tag)
- Private registry without credentials

**Solutions**:
```bash
# Check exact error
kubectl describe pod <pod-name> -n voting-dev

# Add Docker Hub credentials (if rate limited)
kubectl create secret docker-registry dockerhub \
  --docker-username=ibrahim1025 \
  --docker-password=<token> \
  -n voting-dev

# Update deployment to use secret
kubectl patch serviceaccount voting-app-sa \
  -p '{"imagePullSecrets": [{"name": "dockerhub"}]}' \
  -n voting-dev
```

#### 2. Vote App Can't Connect to Redis

**Symptom**: Logs show `redis.exceptions.ConnectionError: Error -2 connecting to redis:6379`

**Cause**: Old image with hardcoded `redis` hostname instead of using `REDIS_HOST` env var

**Solution**:
```bash
# Verify environment variable is set
kubectl exec -n voting-dev deployment/vote -- env | grep REDIS_HOST
# Should show: REDIS_HOST=redis-master

# Check current image
kubectl get deployment vote -n voting-dev -o jsonpath='{.spec.template.spec.containers[0].image}'

# If using old image, trigger rebuild
git commit --allow-empty -m "chore: Rebuild vote image"
git push
```

#### 3. Result Page Blank (White Screen)

**Causes**:
- Worker not creating `votes` table (connection issue)
- Result app can't query PostgreSQL
- JavaScript errors in browser console

**Debugging**:
```bash
# Check if votes table exists
PGPASS=$(kubectl get secret postgresql-credentials -n voting-dev -o jsonpath='{.data.password}' | base64 -d)
kubectl exec -n voting-dev postgresql-0 -- \
  env PGPASSWORD="$PGPASS" psql -U postgres -d votes -c "\dt"

# Check worker logs
kubectl logs -n voting-dev -l app=worker --tail=50

# Check result logs
kubectl logs -n voting-dev -l app=result --tail=50

# Verify PostgreSQL connectivity from result pod
kubectl exec -n voting-dev deployment/result -- nc -zv postgresql 5432
```

#### 4. ALB Not Created / Ingress Pending

**Symptom**: `kubectl get ingress` shows ADDRESS as `<pending>`

**Causes**:
- ALB Controller not installed
- Incorrect annotations
- Insufficient IAM permissions

**Solutions**:
```bash
# Check ALB Controller status
kubectl get deployment -n kube-system aws-load-balancer-controller

# Check controller logs
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# Verify ingress annotations
kubectl get ingress vote-ingress -n voting-dev -o yaml | grep annotations -A 10

# Check ALBs in AWS console
aws elbv2 describe-load-balancers --query 'LoadBalancers[?contains(LoadBalancerName, `k8s-votingde`)].LoadBalancerArn'
```

#### 5. Terraform Apply Fails: State Lock

**Symptom**: `Error acquiring the state lock`

**Cause**: Previous run crashed without releasing lock

**Solution**:
```bash
# Force unlock (use the Lock ID from error message)
cd terraform-infrastructure/environments/dev/eks-cluster
terragrunt force-unlock <LOCK-ID>

# Or delete lock manually from DynamoDB table (last resort)
```

#### 6. GitHub Actions: AWS Credentials Not Working

**Symptom**: `Error: The security token included in the request is invalid`

**Causes**:
- OIDC provider not created
- IAM role trust policy incorrect
- GitHub secret `AWS_ROLE_ARN` wrong

**Solutions**:
```bash
# Verify OIDC provider exists
aws iam list-open-id-connect-providers

# Check IAM role trust policy
aws iam get-role --role-name github-actions-role

# Should contain:
# "Federated": "arn:aws:iam::<account>:oidc-provider/token.actions.githubusercontent.com"
# "Condition": {"StringEquals": {"token.actions.githubusercontent.com:sub": "repo:ibrahemyasser/tactful.ai-devops:*"}}
```

---

## 📚 Additional Documentation

- [AWS OIDC Setup](./AWS_OIDC_SETUP.md) - Detailed GitHub OIDC configuration
- [SSM Setup](./SSM_SETUP.md) - Production bastion access via Session Manager
- [Automation Flow](./AUTOMATION_FLOW.md) - CI/CD pipeline deep dive
- [CI/CD Quick Reference](./CI_CD_QUICK_REF.md) - Command cheat sheet
- [Deployment Guides](./DEPLOYMENT_GUIDE.md) - Step-by-step deployment
- [Helm Implementation](./HELM_IMPLEMENTATION.md) - Chart structure and customization

---

## 📞 Support & Contact

**Repository**: https://github.com/ibrahemyasser/tactful.ai-devops  
**Issues**: Report bugs or request features via GitHub Issues  
**Author**: Ibrahim Yasser  

---

## 📄 License

This project is part of a technical assessment for Tactful.ai and is provided as-is for evaluation purposes.

---

**Last Updated**: November 22, 2025  
**Infrastructure Version**: v1.0  
**Kubernetes Version**: 1.34  
**Terraform Version**: 1.9+
