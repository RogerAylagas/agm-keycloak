---
noteId: "ce704d503a5a11f193731ba5952ee8de"
tags: []

---

# Building Keycloak from Source

This guide explains how to build the AGM Keycloak fork from source using Maven.

## Prerequisites

Before you start, ensure you have:

- **Java 21+** (Keycloak 24+ requires Java 21)
  ```bash
  java -version
  # Expected: openjdk version "21.x.x" or higher
  ```

- **Maven 3.8+**
  ```bash
  mvn -version
  # Expected: Apache Maven 3.8.x or higher
  ```

- **At least 20GB free disk space** (for build artifacts and dependencies)

- **At least 8GB RAM** (more is better for faster builds)

### Installing Prerequisites

#### Ubuntu/Debian:
```bash
sudo apt update
sudo apt install -y openjdk-21-jdk maven
```

#### macOS (with Homebrew):
```bash
brew install openjdk@21 maven
```

#### Windows (with Chocolatey):
```powershell
choco install openjdk21 maven
```

---

## Quick Start

### 1. Navigate to Repository
```bash
cd agm-keycloak
```

### 2. Build Keycloak
```bash
mvn clean install -DskipTests -q
```

**What each flag means:**
- `clean` - Removes previous build artifacts
- `install` - Compiles and packages everything
- `-DskipTests` - Skips running tests (speeds up build; use `-DskipITs` to skip integration tests)
- `-q` - Quiet mode (less verbose output)

**Expected time:** 10-30 minutes depending on your system (first build is slower)

### 3. Verify Build Success
The build completes when you see:
```
BUILD SUCCESS
```

---

## Understanding the Build Output

After a successful build, the distribution is located at:

```
agm-keycloak/quarkus/dist/target/keycloak-999.0.0-SNAPSHOT.tar.gz
```

This tarball contains:
```
keycloak-999.0.0-SNAPSHOT/
├── bin/
│   ├── kc.sh           # Main Keycloak startup script
│   └── kc.bat          # Windows startup script
├── lib/                # All Java libraries
├── conf/               # Configuration directory
├── data/               # Data directory (for embedded database)
├── themes/             # Keycloak UI themes
└── README.md           # Keycloak README
```

---

## Full Build with Tests

To run the complete build including tests:

```bash
mvn clean install
```

**Note:** This is much slower (1-2 hours) and requires more resources. Use this only when making changes to the core code.

---

## Useful Build Commands

### Build only the Quarkus distribution (faster)
```bash
mvn clean install -pl quarkus/dist -DskipTests
```

### Build with verbose output (for debugging)
```bash
mvn clean install -DskipTests
```

### Build and skip all tests but keep integration test compilation
```bash
mvn clean install -DskipTests -DskipITs=false
```

### Skip downloading dependencies (uses cached versions)
```bash
mvn clean install -DskipTests -o  # Note: -o for offline mode
```

### Force download dependencies (useful if corrupted)
```bash
mvn clean install -DskipTests -U
```

---

## Troubleshooting

### Issue: "No compiler is provided in this environment"
**Cause:** Java not properly installed or JAVA_HOME not set

**Solution:**
```bash
# Set JAVA_HOME explicitly
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64  # Linux
# or
export JAVA_HOME=$(/usr/libexec/java_home -v 21)     # macOS

mvn clean install -DskipTests -q
```

### Issue: "Cannot find symbol" or compilation errors
**Cause:** Java version mismatch (using Java 11 instead of 21)

**Solution:**
```bash
# Verify Java version
java -version
javac -version

# If wrong version, update JAVA_HOME or switch Java version
# Ubuntu:
sudo update-alternatives --config java
sudo update-alternatives --config javac
```

### Issue: "OutOfMemoryError" during build
**Cause:** Not enough RAM allocated to Maven

**Solution:**
```bash
# Increase Maven heap size
export MAVEN_OPTS="-Xmx2048m"
mvn clean install -DskipTests -q
```

### Issue: "Failed to download" or network errors
**Cause:** Maven repositories are unreachable or network issues

**Solution:**
```bash
# Try with repository retries
mvn clean install -DskipTests -q -Dmaven.wagon.http.retryHandler.count=5

# Or use offline mode if you've built before
mvn clean install -DskipTests -q -o
```

### Issue: Build takes very long time
**Cause:** First build downloads all dependencies, or your system is slow

**Solution:**
- First build is expected to take 15-30 minutes
- Subsequent builds are much faster (5-10 minutes) due to cached dependencies
- If building is consistently slow, consider:
  - Building only Quarkus: `mvn clean install -pl quarkus/dist -DskipTests`
  - Using `-o` flag if dependencies are cached

---

## Build on Different Platforms

### Linux
```bash
mvn clean install -DskipTests -q
```

### macOS
```bash
export JAVA_HOME=$(/usr/libexec/java_home -v 21)
mvn clean install -DskipTests -q
```

### Windows (PowerShell)
```powershell
$env:JAVA_HOME="C:\Program Files\OpenJDK\openjdk-21"
mvn clean install -DskipTests -q
```

---

## Next Steps

After a successful build:

1. **Run locally with Docker Compose** → See `docs/LOCAL_DEV.md`
2. **Create Docker image** → See `docs/BUILD.md` (Step 1.2)
3. **Deploy to Kubernetes** → See `docs/KUBERNETES.md`

---

## CI/CD Integration

The Maven build is automatically triggered in GitHub Actions when you:
- Push to the `main` branch
- Create a git tag (v1.0.0, etc.)

See `.github/workflows/release.yml` for the full pipeline.

---

## Advanced: Building with Custom Extensions

If you've added custom Keycloak providers or extensions:

```bash
mvn clean install -DskipTests -pl "quarkus/server,quarkus/dist" -q
```

This rebuilds the server with your extensions included.

---

## Getting Help

- **Maven troubleshooting:** `mvn help:active-profiles`
- **Check Java compiler:** `javac -version`
- **Show build process:** Remove `-q` flag for verbose output
- **Debug mode:** Add `-X` flag for extra debug information
