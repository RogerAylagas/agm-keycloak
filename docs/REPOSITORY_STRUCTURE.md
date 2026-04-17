---
noteId: "33a03b903a5b11f193731ba5952ee8de"
tags: []

---

# AGM Keycloak Repository Structure

This document explains the directory structure of the agm-keycloak fork and what each component does.

## High-Level Overview

```
agm-keycloak/
├── quarkus/              # 🔴 MOST IMPORTANT - Keycloak server runtime
├── core/                 # Core Keycloak functionality
├── docs/                 # Documentation (including this file)
├── distribution/         # Distribution packaging
├── services/             # Keycloak services
├── federation/           # User federation (LDAP, custom providers)
├── adapters/             # Application adapters (Spring, etc.)
├── k8s/                  # Kubernetes manifests (we'll create this)
├── compose/              # Docker Compose setup (we'll create this)
├── pom.xml               # Maven root POM (project configuration)
├── Dockerfile            # Docker build file (we'll create this)
├── .github/workflows/    # GitHub Actions CI/CD pipelines
└── README.md             # Original Keycloak README
```

---

## Key Directories for AGM

### 🔴 `quarkus/` - The Server We Build
This is what gets packaged into the Docker image:

```
quarkus/
├── server/               # Keycloak Quarkus server implementation
├── runtime/              # Runtime configuration and startup
├── deployment/           # Quarkus deployment config
├── dist/                 # Distribution packaging
│   └── target/           # 📦 BUILD OUTPUT: keycloak-999.0.0-SNAPSHOT.tar.gz
├── container/            # Container/Docker related files
│   ├── Dockerfile        # Keycloak official Dockerfile template
│   └── ubi-null.sh       # UBI (Universal Base Image) configuration
└── tests/                # Quarkus-specific tests
```

**This is the most important directory for our Docker image.**

---

### `core/` - Core Keycloak Features
Low-level Keycloak functionality:

```
core/
├── authorization-services/  # Fine-grained authorization
├── account-api/             # User account management
├── authentication/          # Authentication mechanisms (password, OTP, WebAuthn)
├── email/                   # Email sending (SMTP configuration)
├── events/                  # Event logging and listeners
├── crypto/                  # Cryptography and encryption
└── ...more internal modules
```

**You typically don't modify this, unless adding custom authentication providers.**

---

### `services/` - Business Logic Services
High-level Keycloak services:

```
services/
├── src/main/java/org/keycloak/services/
├── resources/               # REST API endpoints (realms, users, clients)
├── managers/                # Business logic managers
├── listeners/               # Event listeners
└── ...
```

**If you add custom REST endpoints, they go here.**

---

### `federation/` - User Federation & Providers
Connect Keycloak to external identity sources:

```
federation/
├── ldap/                    # LDAP/Active Directory integration
├── kerberos/                # Kerberos/SPNEGO support
├── sssd/                    # SSSD (System Security Services Daemon)
└── custom/                  # Custom federation providers
```

**If AGM needs to connect to LDAP or custom auth systems, customize here.**

---

### `adapters/` - Application Integrations
Libraries for integrating applications with Keycloak:

```
adapters/
├── spring-boot-adapter/     # Spring Boot integration
├── oidc/                    # OpenID Connect client library
├── saml/                    # SAML 2.0 adapter
└── ...
```

**Not needed for server build, but useful for client applications.**

---

### `distribution/` - Packaging & Distribution
Configuration for building distributions:

```
distribution/
├── downloads/               # Download dependencies
├── galleon-feature-packs/   # Feature packs for custom builds
├── licenses-common/         # License files
└── maven-plugins/           # Custom Maven plugins
```

**Used during the Maven build process.**

---

## Build Process Flow

When you run `mvn clean install -DskipTests`:

```
1. Root pom.xml
   │
   └─→ Builds all modules (core, services, federation, etc.)
       │
       └─→ quarkus/server
           │
           └─→ Compiles Keycloak server with Quarkus runtime
               │
               └─→ quarkus/dist
                   │
                   └─→ Packages into: quarkus/dist/target/keycloak-999.0.0-SNAPSHOT.tar.gz
                       │
                       └─→ Contains runnable Keycloak server!
```

---

## Important Files for Development

### Configuration Files

| File | Purpose |
|------|---------|
| `pom.xml` | Maven project configuration and dependencies |
| `quarkus/server/pom.xml` | Keycloak Quarkus server configuration |
| `.github/workflows/` | GitHub Actions CI/CD pipelines |

### Documentation Files

| File | Purpose |
|------|---------|
| `docs/building.md` | Official Keycloak build guide |
| `docs/tests.md` | How to run tests |
| `CONTRIBUTING.md` | Contributing guidelines |
| `LICENSE.txt` | Apache 2.0 License |

### Docker Files

| File | Purpose |
|------|---------|
| `quarkus/container/Dockerfile` | Official Keycloak Dockerfile |
| `quarkus/container/ubi-null.sh` | UBI image minimization script |

---

## Where We'll Add AGM-Specific Content

### 1. Configuration & Realm Setup
```
agm-keycloak/
├── k8s/
│   ├── configmaps/
│   │   └── agm-realm-export.json  ← AGM realm definition
│   └── secrets/
│       └── admin-credentials      ← Admin user credentials
└── compose/
    └── agm-realm-export.json      ← Same realm for docker-compose
```

### 2. Realm Initialization Script
```
agm-keycloak/
└── docker-entrypoint.sh           ← Auto-imports realm on container startup
```

### 3. Custom Keycloak Providers (Future)
If AGM adds custom authentication or user federation:
```
agm-keycloak/
├── providers/                     ← Custom Keycloak extensions
│   ├── agm-authenticator/
│   │   └── pom.xml
│   └── pom.xml
└── quarkus/
    └── server/
        └── pom.xml                ← Will reference custom providers
```

### 4. Kubernetes & Docker Compose
```
agm-keycloak/
├── k8s/                           ← Kubernetes manifests
│   ├── base/
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── configmap.yaml
│   │   └── secret.yaml
│   └── overlays/
│       ├── local/
│       ├── aws-eks/
│       └── azure-aks/
└── compose/
    └── docker-compose.yaml        ← Local development setup
```

---

## Build Artifacts Location

After successful build, look for:

```bash
# Main Keycloak distribution (used for Docker image)
agm-keycloak/quarkus/dist/target/keycloak-999.0.0-SNAPSHOT.tar.gz

# Extracting it shows:
keycloak-999.0.0-SNAPSHOT/
├── bin/
│   └── kc.sh                      ← Startup script (entry point in Docker)
├── lib/                           ← All Java JAR files
├── conf/                          ← Configuration files
├── data/                          ← Data directory (volumes in Docker/K8s)
├── themes/                        ← Keycloak UI themes
└── providers/                     ← Custom providers/extensions
```

---

## Understanding Module Dependencies

The build order is important because modules depend on each other:

```
common/                    (Low-level utilities)
    ↓
server-spi/               (Server Plugin Interface)
    ↓
core/                     (Core functionality)
    ↓
services/                 (High-level services)
    ↓
federation/               (User federation)
    ↓
authz/                    (Authorization services)
    ↓
quarkus/server/           (Keycloak server)
    ↓
quarkus/dist/             (🎁 Final distribution package)
```

If a module has build errors, modules that depend on it will also fail.

---

## Common Commands for This Repository

```bash
# Build everything
mvn clean install -DskipTests

# Build only Keycloak server (faster)
mvn clean install -DskipTests -pl quarkus/dist

# Build with verbose output
mvn clean install -DskipTests -X

# Run Keycloak tests
mvn clean install  # runs tests by default

# Run only unit tests (no integration tests)
mvn clean install -DskipUnitTests=false -DskipIntegrationTests=true

# Run specific module tests
mvn clean install -pl quarkus/server -DskipTests=false
```

---

## Next Steps

1. **Build completes** → See `docs/BUILD.md`
2. **Create Docker image** → See Step 1.2 in main documentation
3. **Understand Keycloak concepts** → See `docs/KEYCLOAK_GUIDE.md` (we'll create this)
4. **Deploy to Kubernetes** → See `docs/KUBERNETES.md`

---

## Learn More

- [Official Keycloak Documentation](https://www.keycloak.org/documentation)
- [Keycloak Architecture](https://www.keycloak.org/docs/latest/server_admin/)
- [Keycloak GitHub](https://github.com/keycloak/keycloak)
