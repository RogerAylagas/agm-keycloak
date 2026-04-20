---
noteId: "17887b003cba11f1903ecf914e8ff254"
tags: []

---

# AGM Keycloak Container Deployment Guide

This guide explains how to run AGM Keycloak using Docker/Kubernetes and how to switch between local and cloud deployments.

## Quick Start — Local Docker Compose

### Prerequisites
- Docker (version 20+)
- Docker Compose (version 2+)
- Ports 80, 443, 8080, 5432 available

### Run Locally
```bash
cd deploy/compose
cp .env.example .env
# (Edit .env with custom passwords if desired)
docker compose up -d
```

**Access Keycloak:**
- Admin Console: http://localhost/admin/ (via Nginx reverse proxy on port 80)
- Direct access: http://localhost:8080

**Services running:**
- Keycloak: http://localhost:8080
- PostgreSQL: localhost:5432 (internal)
- Nginx: http://localhost (reverse proxy, TLS termination)

### Stop Services
```bash
docker compose down
```

### View Logs
```bash
docker compose logs keycloak    # Keycloak logs
docker compose logs postgres    # Database logs
docker compose logs nginx       # Reverse proxy logs
docker compose logs -f keycloak # Follow logs (Ctrl+C to exit)
```

---

## Deployment Types

### 1. Local Development (Docker Compose)

**Best for:** Development, testing, local prototyping

**Configuration:** `deploy/compose/docker-compose.yml`

**Database:** In-cluster PostgreSQL (container)

**Networking:** Local Docker network (`agm-net`)

**TLS:** Nginx with self-signed certificate

**How to deploy:**
```bash
cd deploy/compose
docker compose up -d
```

**Environment variables** (`.env`):
- `KC_ADMIN_PASSWORD` — Keycloak admin password
- `KC_DB_PASSWORD` — PostgreSQL password
- `KC_HOSTNAME` — Keycloak hostname (default: `localhost`)

---

### 2. Kubernetes — Local (minikube/kind)

**Best for:** Local Kubernetes testing, development

**Configuration:** `deploy/helm/agm-keycloak/values-local.yaml`

**Database:** In-cluster PostgreSQL (StatefulSet)

**Networking:** Kubernetes Ingress (nginx)

**TLS:** Let's Encrypt via cert-manager (optional) or self-signed

**How to deploy:**
```bash
# Prerequisites: minikube/kind cluster running, helm installed

cd deploy/helm
helm install agm-keycloak agm-keycloak \
  -f agm-keycloak/values.yaml \
  -f agm-keycloak/values-local.yaml \
  -n keycloak --create-namespace

# Or use convenience script
chmod +x ../../scripts/k8s-deploy.sh
../../scripts/k8s-deploy.sh local
```

**Access Keycloak:**
```bash
# Add to /etc/hosts:
127.0.0.1 keycloak.local

# Visit: http://keycloak.local
```

**Verify deployment:**
```bash
kubectl get pods -n keycloak
kubectl get svc -n keycloak
kubectl get ingress -n keycloak
```

---

### 3. AWS EKS + RDS

**Best for:** Production on AWS

**Configuration:** `deploy/helm/agm-keycloak/values-aws.yaml`

**Database:** AWS RDS (managed PostgreSQL) — external to cluster

**Networking:** AWS ALB (Application Load Balancer)

**Secrets:** AWS Secrets Manager + External Secrets Operator

**TLS:** ACM (AWS Certificate Manager)

**Prerequisites:**
- EKS cluster running
- RDS PostgreSQL instance provisioned
- IRSA (IAM Roles for Service Accounts) configured
- External Secrets Operator installed
- AWS Secrets Manager with keycloak/admin-password and keycloak/db-password

**How to deploy:**
```bash
# 1. Create RDS instance (e.g., postgres 15-alpine, 20GB, db.t3.small)

# 2. Create secrets in AWS Secrets Manager
aws secretsmanager create-secret \
  --name keycloak/admin-password \
  --secret-string "your-admin-password"

aws secretsmanager create-secret \
  --name keycloak/db-password \
  --secret-string "your-db-password"

# 3. Update values-aws.yaml with:
# - RDS endpoint
# - ACM certificate ARN
# - IRSA role ARN

# 4. Deploy
./scripts/k8s-deploy.sh aws

# Or manually:
helm install agm-keycloak agm-keycloak \
  -f agm-keycloak/values.yaml \
  -f agm-keycloak/values-aws.yaml \
  -n keycloak --create-namespace
```

**Access Keycloak:**
```bash
kubectl get ingress -n keycloak
# Note the ALB DNS name, create Route 53 CNAME record
```

---

### 4. Google Cloud (GKE) + Cloud SQL

**Best for:** Production on Google Cloud

**Configuration:** `deploy/helm/agm-keycloak/values-gcp.yaml`

**Database:** Cloud SQL (managed PostgreSQL) — external to cluster

**Networking:** Google Cloud Load Balancer (external LB)

**Secrets:** Google Secret Manager + External Secrets Operator

**TLS:** Google-managed SSL certificate

**Prerequisites:**
- GKE cluster running
- Cloud SQL PostgreSQL instance provisioned
- Workload Identity configured
- External Secrets Operator installed

**How to deploy:**
```bash
# 1. Create Cloud SQL instance

# 2. Create secrets in Google Secret Manager
gcloud secrets create keycloak-admin-password \
  --replication-policy="automatic" \
  --data-file=- <<< "your-admin-password"

gcloud secrets create keycloak-db-password \
  --replication-policy="automatic" \
  --data-file=- <<< "your-db-password"

# 3. Configure Workload Identity
gcloud iam service-accounts create keycloak-sa
gcloud secrets add-iam-policy-binding keycloak-admin-password \
  --member=serviceAccount:keycloak-sa@PROJECT_ID.iam.gserviceaccount.com \
  --role=roles/secretmanager.secretAccessor

# 4. Update values-gcp.yaml with Cloud SQL instance connection name

# 5. Deploy
./scripts/k8s-deploy.sh gcp
```

---

### 5. Azure (AKS) + Azure Database

**Best for:** Production on Azure

**Configuration:** `deploy/helm/agm-keycloak/values-azure.yaml`

**Database:** Azure Database for PostgreSQL (managed) — external to cluster

**Networking:** Azure Application Gateway (AGIC)

**Secrets:** Azure Key Vault + External Secrets Operator

**TLS:** Azure-managed certificate or Let's Encrypt via cert-manager

**Prerequisites:**
- AKS cluster running
- Azure Database for PostgreSQL provisioned
- Workload Identity (OIDC federation) configured
- External Secrets Operator installed

**How to deploy:**
```bash
# 1. Create Azure DB for PostgreSQL

# 2. Create secrets in Azure Key Vault
az keyvault secret set --vault-name keycloak-vault \
  --name admin-password \
  --value "your-admin-password"

az keyvault secret set --vault-name keycloak-vault \
  --name db-password \
  --value "your-db-password"

# 3. Configure Workload Identity (OIDC federation)
# See Azure docs for setup steps

# 4. Update values-azure.yaml with:
# - Azure DB FQDN
# - Federated identity client ID
# - Key Vault name

# 5. Deploy
./scripts/k8s-deploy.sh azure
```

---

## Switching Between Deployment Types

### From Local Docker Compose → Kubernetes (Local)

**Backup database (if needed):**
```bash
cd deploy/compose
docker compose exec postgres pg_dump -U keycloak keycloak > /tmp/keycloak-backup.sql
docker compose down
```

**Deploy on Kubernetes:**
```bash
helm install agm-keycloak agm-keycloak \
  -f deploy/helm/agm-keycloak/values.yaml \
  -f deploy/helm/agm-keycloak/values-local.yaml
```

**Restore database (optional):**
```bash
kubectl exec -it deployment/agm-keycloak-postgres -- \
  psql -U keycloak keycloak < /tmp/keycloak-backup.sql
```

### From Local Development → AWS Production

**Steps:**
1. Ensure all realm/user/client configuration is in git (use realm export)
2. Create AWS infrastructure (EKS, RDS, Secrets Manager)
3. Update `values-aws.yaml` with infrastructure details
4. Deploy to AWS using `helm install` with `values-aws.yaml`
5. Configure DNS to point to AWS ALB
6. Test SSL certificate and DNS resolution
7. Validate users can login via Keycloak

**Important:** Production deployments should:
- Use strong passwords (not dev defaults)
- Enable TLS/HTTPS
- Configure backup policies for RDS
- Set up monitoring and logging
- Enable audit logging in Keycloak
- Restrict admin access (strong passwords, 2FA if available)

---

## Configuration Reference

### Environment Variables (docker-compose)

| Variable | Default | Description |
|----------|---------|-------------|
| `KC_ADMIN_USER` | `admin` | Keycloak admin username |
| `KC_ADMIN_PASSWORD` | `changeme` | Keycloak admin password |
| `KC_DB_NAME` | `keycloak` | PostgreSQL database name |
| `KC_DB_USER` | `keycloak` | PostgreSQL user |
| `KC_DB_PASSWORD` | `changeme` | PostgreSQL password |
| `KC_HOSTNAME` | `localhost` | Keycloak hostname (for redirects) |

### Helm Values Reference

Base: `deploy/helm/agm-keycloak/values.yaml`

Key configurable options:
```yaml
keycloak:
  replicas: 1                    # Number of Keycloak pods
  hostname: keycloak.local       # Public hostname
  importRealm: true              # Auto-import realm on startup
  
database:
  provider: local                # local | rds | cloudsql | azuredb
  postgresql:
    enabled: true                # false on cloud (uses managed DB)
    storage:
      size: 10Gi                 # PVC size for local PostgreSQL

nginx:
  enabled: true                  # false on cloud (uses managed LB)
  tls:
    enabled: false               # Enable TLS termination

ingress:
  enabled: true
  className: nginx               # Change to: alb | gce | azure/application-gateway
  host: keycloak.local
```

---

## Troubleshooting

### Docker Compose Issues

**Container won't start:**
```bash
docker compose logs keycloak
# Check for:
# - Port 8080 already in use
# - Database connection errors
# - Memory/CPU constraints
```

**Database connection error:**
```bash
docker compose exec postgres pg_isready -U keycloak
# If not healthy, restart postgres:
docker compose restart postgres
```

**Port conflicts:**
```bash
lsof -i :8080
# Kill existing process or use different port in .env
```

### Kubernetes Issues

**Pod stuck in Pending:**
```bash
kubectl describe pod <pod-name> -n keycloak
# Check for: PVC issues, node resources, image pull errors
```

**CrashLoopBackOff:**
```bash
kubectl logs <pod-name> -n keycloak
# Check Keycloak startup errors
```

**Ingress not working:**
```bash
kubectl get ingress -n keycloak
# Verify ingress controller is installed and has IP
kubectl get ingressclass
```

---

## Realm Import (AGM Configuration)

The default realm (`AGM`) with users is automatically imported on first deployment:

**Users created:**
- `agm-admin` — Admin user (realm admin role)
- `user-engineer` — Engineering user
- `user-finance` — Finance user

All passwords are `changeme` for development. Change immediately in production!

**To re-import realm:**
```bash
# Delete existing realm and restart
kubectl delete realm agm -n keycloak
helm uninstall agm-keycloak -n keycloak
helm install agm-keycloak agm-keycloak -f values.yaml
```

---

## Production Checklist

- [ ] Use strong, unique passwords (not defaults)
- [ ] Enable TLS/HTTPS for all traffic
- [ ] Configure automated backups (RDS/Cloud SQL)
- [ ] Set up monitoring (CloudWatch/Cloud Monitoring/Azure Monitor)
- [ ] Enable audit logging in Keycloak
- [ ] Restrict admin console access (firewall rules)
- [ ] Configure SMTP for email notifications
- [ ] Test disaster recovery procedures
- [ ] Document runbooks for common operations
- [ ] Set up alerting for failures/downtime

---

## References

- [Keycloak Operator Documentation](https://www.keycloak.org/docs/latest/server_admin/)
- [Helm Chart Docs](https://helm.sh/docs/)
- [Docker Compose Reference](https://docs.docker.com/compose/compose-file/)
- [Kubernetes Ingress Docs](https://kubernetes.io/docs/concepts/services-networking/ingress/)
