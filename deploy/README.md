---
noteId: "719499b03c8f11f1903ecf914e8ff254"
tags: []

---

# AGM Keycloak Deployment

This directory contains all containerization and deployment artifacts for AGM Keycloak.

## Directory Structure

```
deploy/
├── docker/                   # Docker images
│   ├── Dockerfile           # AGM Keycloak image (extends official quay.io base)
│   ├── Dockerfile.source    # Source build path (Phase 3 when custom code added)
│   └── nginx/               # Nginx reverse proxy
│
├── compose/                 # Local Docker Compose development
│   ├── docker-compose.yml   # Main stack (KC + PG + Nginx)
│   ├── docker-compose.override.yml  # Dev mode overrides
│   └── .env.example         # Secrets template (copy to .env)
│
└── helm/                    # Kubernetes deployment via Helm
    └── agm-keycloak/
        ├── Chart.yaml       # Chart metadata
        ├── values.yaml      # Base values (provider-neutral)
        ├── values-local.yaml    # minikube/kind overrides
        ├── values-aws.yaml      # EKS + RDS overrides
        ├── values-gcp.yaml      # GKE + Cloud SQL overrides
        ├── values-azure.yaml    # AKS + Azure DB overrides
        └── templates/       # Kubernetes manifests
            ├── keycloak/    # Keycloak deployment + service + ingress
            ├── postgres/    # PostgreSQL statefulset (conditional)
            ├── nginx/       # Nginx reverse proxy (conditional)
            └── serviceaccount.yaml
```

---

## Local Development: Docker Compose

### Quick Start

```bash
cd deploy/compose
cp .env.example .env
# Edit .env with your passwords (dev-only values provided)
docker-compose up
```

**Access:**
- Keycloak Admin: http://localhost:8080/admin
- Via Nginx proxy: http://localhost/admin
- Default creds: admin / admin (from .env)

### Dev vs. Production Mode

Docker Compose uses two files:

1. **`docker-compose.yml`** — Production-like mode
   - `start --optimized` (fast startup, TLS-ready)
   - No auto-import on pod restart

2. **`docker-compose.override.yml`** (optional) — Dev mode
   - `start-dev` (debug-friendly)
   - Hot reload on code changes (when available)

Compose automatically merges both files when both are present. To run production-like:

```bash
docker-compose -f docker-compose.yml up
```

### Custom Keycloak Image

The Dockerfile at `docker/Dockerfile` extends the official `quay.io/keycloak/keycloak:26.1.4` image and:
- Runs Quarkus build optimization (`kc.sh build`) for fast startup
- Copies realm config for auto-import
- Sets PostgreSQL as the database

To build locally without compose:

```bash
cd ../..
docker build -f deploy/docker/Dockerfile -t agm-keycloak:dev .
```

---

## Kubernetes: Helm Chart

### Prerequisites

- Kubernetes cluster (minikube, kind, EKS, GKE, AKS, etc.)
- `helm` 3.14+
- `kubectl` configured

### Local K8s Deployment (minikube/kind)

```bash
# Create cluster (if needed)
minikube start

# Deploy
cd deploy/helm
helm install agm-keycloak agm-keycloak \
  -f agm-keycloak/values.yaml \
  -f agm-keycloak/values-local.yaml

# Or use the convenience script
cd ../..
chmod +x scripts/k8s-deploy.sh
./scripts/k8s-deploy.sh local
```

**Verify:**
```bash
kubectl get pods -l app.kubernetes.io/instance=agm-keycloak
kubectl get ingress
```

**Access:**
- Add `127.0.0.1 keycloak.local` to `/etc/hosts`
- Visit http://keycloak.local/admin

### AWS EKS + RDS Deployment

1. Create EKS cluster and RDS PostgreSQL instance
2. Configure IRSA (IAM Roles for Service Accounts) for secrets access
3. Deploy secrets to AWS Secrets Manager
4. Update `values-aws.yaml` with:
   - RDS endpoint
   - ACM certificate ARN
   - IRSA role ARN

```bash
./scripts/k8s-deploy.sh aws
```

### GCP GKE + Cloud SQL Deployment

1. Create GKE cluster and Cloud SQL PostgreSQL instance
2. Configure Workload Identity
3. Deploy secrets to GCP Secret Manager
4. Update `values-gcp.yaml` with:
   - Cloud SQL instance connection name
   - Workload Identity service account email

```bash
./scripts/k8s-deploy.sh gcp
```

### Azure AKS + Azure Database Deployment

1. Create AKS cluster and Azure Database for PostgreSQL
2. Configure Workload Identity (OIDC federation)
3. Deploy secrets to Azure Key Vault
4. Update `values-azure.yaml` with:
   - Azure DB FQDN
   - Federated identity client ID

```bash
./scripts/k8s-deploy.sh azure
```

---

## Helm Chart Values

### Base Values (`values.yaml`)

All provider-neutral defaults. Key configuration:

```yaml
cloud:
  provider: local                  # local | aws | gcp | azure

keycloak:
  hostname: required              # MUST be set per environment
  replicas: 1                      # Scales to 2+ for cloud
  importRealm: true               # Auto-import agm-realm.json on first deploy

database:
  provider: local                 # local | rds | cloudsql | azuredb
  postgresql:
    enabled: true                 # false on cloud (uses managed DB)

nginx:
  enabled: true                   # false on cloud (uses managed LB)

secrets:
  existingSecret: ""              # Set on cloud (External Secrets Operator)
```

### Environment Overrides

- **`values-local.yaml`** — in-cluster PostgreSQL, Nginx enabled
- **`values-aws.yaml`** — RDS, no Nginx, ALB ingress, IRSA
- **`values-gcp.yaml`** — Cloud SQL, no Nginx, GCE LB, Workload Identity
- **`values-azure.yaml`** — Azure DB, no Nginx, AGIC, Workload Identity

---

## CI/CD: GitHub Actions

Two workflows are in `.github/workflows/`:

### 1. `pr-checks.yml` — Validate on PRs
- Helm lint
- Docker build (no push)

Trigger: Pull request to main/develop

### 2. `build-push.yml` — Build and push to GHCR
- Builds Keycloak + Nginx images
- Pushes to `ghcr.io/RogerAylagas/agm-keycloak`
- Auto-bumps Helm `Chart.yaml appVersion`

Trigger: Semver git tag (`v1.0.0`, `v2.3.4`, etc.)

```bash
# Tag and push to trigger CI/CD
git tag v0.1.0
git push origin v0.1.0
```

**Image tags produced:**
- `0.1.0` (full semver)
- `0.1` (major.minor)
- `0` (major only)
- `sha-<commit>` (short SHA)

---

## Realm Configuration

The `realm-config/agm-realm.json` (created in Phase 2) is copied into the Keycloak image and auto-imported on first deployment:

- **Docker:** Auto-imported by `--import-realm` in compose
- **Kubernetes:** Imported by a Job on first `helm install` (via Helm post-install hook)

After initial deploy, the realm is NOT re-imported on pod restart (to prevent overwriting manual admin changes). To re-import:

```bash
# Delete the realm and helm install again
kubectl delete realm agm
helm uninstall agm-keycloak
helm install agm-keycloak agm-keycloak -f values.yaml -f values-local.yaml
```

---

## Secrets Management

### Local Development (docker-compose)

Use `.env` file (never committed):

```bash
cp .env.example .env
# Edit passwords
docker-compose up
```

### Local K8s (kubectl)

Create secrets manually once:

```bash
kubectl create secret generic agm-keycloak-secrets \
  --from-literal=admin-password=<YOUR_PASSWORD> \
  --from-literal=db-password=<YOUR_PASSWORD>
```

Helm references this secret in the Deployment.

### Cloud (External Secrets Operator)

For AWS/GCP/Azure, use External Secrets Operator + native secret stores:

1. Install ESO: `helm repo add external-secrets https://charts.external-secrets.io`
2. Create `ExternalSecret` to sync from native store
3. Set `secrets.existingSecret: agm-keycloak-secrets` in values

ESO will populate the K8s Secret automatically.

---

## Troubleshooting

### Docker Compose
- **Port 8080 in use:** `lsof -i :8080` and kill the process
- **"No such file" error:** Ensure COPY paths in Dockerfile are correct
- **Database connection error:** Check PostgreSQL is healthy: `docker-compose ps`

### Kubernetes
- **Pod stuck in Pending:** Check PVC: `kubectl get pvc` and node resources
- **CrashLoopBackOff:** Check logs: `kubectl logs -f <pod-name>`
- **Ingress not working:** Verify ingress controller is installed and has IP: `kubectl get ingress`

### Helm
- **Template error:** Validate: `helm template agm-keycloak agm-keycloak -f values-local.yaml`
- **Secret not found:** Ensure secret exists: `kubectl get secret agm-keycloak-secrets`

---

## Next Steps

- **Phase 3:** Add custom Keycloak extensions (providers, themes, SPI)
  - Update `Dockerfile` to COPY providers/ and themes/
  - No other changes needed (Helm, compose, CI/CD stay the same)

- **Production hardening:**
  - Enable TLS in Nginx / managed LB
  - Use cert-manager with Let's Encrypt on K8s
  - Set up autoscaling (HPA) on cloud
  - Configure logging / monitoring sidecar
  - Use External Secrets Operator for all environments

---

## References

- [Keycloak Admin REST API](https://www.keycloak.org/docs/latest/server_admin/#admin-rest-api)
- [Helm Documentation](https://helm.sh/docs/)
- [PostgreSQL Helm Chart](https://github.com/bitnami/charts/tree/main/bitnami/postgresql)
