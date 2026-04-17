# AGM Keycloak Setup Scripts

Automated scripts for building and running Keycloak locally.

## Quick Start

### Option 1: Bash Script (Linux/macOS)

```bash
cd /home/usuario/Desktop/AGM-Dev/agm-keycloak
./scripts/phase1-setup.sh all
```

### Option 2: Python Script (Cross-platform: Linux/macOS/Windows)

```bash
cd /home/usuario/Desktop/AGM-Dev/agm-keycloak
python3 scripts/phase1_setup.py all
```

Both scripts do the same thing — pick whichever is available on your system.

---

## Scripts Overview

### `phase1-setup.sh` (Bash)
- **Platform:** Linux, macOS
- **Language:** Bash
- **Size:** ~300 lines
- **Features:** Native shell integration, colors, proper error handling

### `phase1_setup.py` (Python)
- **Platform:** Linux, macOS, Windows
- **Language:** Python 3.6+
- **Size:** ~400 lines
- **Features:** Cross-platform, same functionality as Bash version

---

## Available Commands

### Check Prerequisites
Verify Java, Maven, disk space, and project structure.

```bash
# Bash
./scripts/phase1-setup.sh check-prereqs

# Python
python3 scripts/phase1_setup.py check-prereqs
```

Output:
```
✓ Java installed: 21.0.10
✓ Maven installed: Apache Maven 3.6.3
✓ Disk space: 50 GB available
✓ Project directory: /home/usuario/Desktop/AGM-Dev/agm-keycloak
✓ All prerequisites met!
```

---

### Free Port 8080
Stop any process using port 8080 (Traefik, previous Keycloak, etc).

```bash
# Bash
./scripts/phase1-setup.sh free-port

# Python
python3 scripts/phase1_setup.py free-port
```

---

### Build Keycloak
Build the Quarkus server (44 modules, ~2-3 minutes).

```bash
# Bash
./scripts/phase1-setup.sh build

# Python
python3 scripts/phase1_setup.py build
```

**What it does:**
- Runs: `./mvnw -pl quarkus/server -am -DskipTests clean install`
- Skips the JS/admin UI build (avoids pnpm symlink errors)
- Creates artifacts in `quarkus/server/target/`

---

### Run Keycloak
Start Keycloak in dev mode with admin credentials pre-configured.

```bash
# Bash
./scripts/phase1-setup.sh run

# Python
python3 scripts/phase1_setup.py run
```

**What it does:**
- Creates admin user: `admin` / `admin`
- Starts server on: `http://localhost:8080`
- Enables live coding for dev changes
- Attaches debugger on port 5005

---

### Full Setup (All Steps)
Execute all steps: check prerequisites → free port → build → run.

```bash
# Bash
./scripts/phase1-setup.sh all

# Python
python3 scripts/phase1_setup.py all
```

This is the default if no command is provided:
```bash
./scripts/phase1-setup.sh    # defaults to 'all'
python3 scripts/phase1_setup.py    # defaults to 'all'
```

---

### Verify Installation
Check if Keycloak is running and accessible.

```bash
# Bash
./scripts/phase1-setup.sh verify

# Python
python3 scripts/phase1_setup.py verify
```

Output:
```
✓ Port 8080 is listening
✓ Admin console is accessible

✓ Keycloak is running and accessible!

ℹ Access the admin console at:
  http://localhost:8080/admin

ℹ Login with:
  Username: admin
  Password: admin
```

---

## Step-by-Step Execution Examples

### Scenario 1: Full Setup from Scratch

```bash
# Option A: All in one command
./scripts/phase1-setup.sh all

# Option B: Step by step
./scripts/phase1-setup.sh check-prereqs
./scripts/phase1-setup.sh free-port
./scripts/phase1-setup.sh build
./scripts/phase1-setup.sh run
```

### Scenario 2: Build Already Done, Just Run Server

```bash
./scripts/phase1-setup.sh run
```

### Scenario 3: Port Conflict, Need to Free It First

```bash
./scripts/phase1-setup.sh free-port
./scripts/phase1-setup.sh run
```

### Scenario 4: Check if Everything is Working

```bash
./scripts/phase1-setup.sh verify
```

---

## Troubleshooting

### "Port already in use: 8080"

```bash
./scripts/phase1-setup.sh free-port
```

This kills any process on port 8080. Common culprits:
- Traefik from `agm-stack`
- Previous Keycloak instance
- Other development services

### "Build failed: pnpm symlink error"

This shouldn't happen with these scripts (they skip JS build), but if you're using a different build command:

```bash
# Don't do this (causes pnpm error):
./mvnw clean install -Pdistribution

# Do this instead (what our scripts use):
./mvnw -pl quarkus/server -am -DskipTests clean install
```

### "Java not found"

Install JDK 21+:
```bash
# Ubuntu/Debian
sudo apt install default-jdk

# macOS
brew install openjdk@21

# Or download from https://www.oracle.com/java/technologies/downloads/
```

### "Maven not found"

Install Maven:
```bash
# Ubuntu/Debian
sudo apt install maven

# macOS
brew install maven

# Or download from https://maven.apache.org/download.cgi
```

### "Cannot reach admin console"

1. Check if server is running:
   ```bash
   ./scripts/phase1-setup.sh verify
   ```

2. Check logs (if running in background):
   ```bash
   tail -f keycloak_dev.log  # if running with output redirected
   ```

3. Wait 30 seconds — server takes time to bootstrap
4. Try accessing in browser: `http://localhost:8080/admin`

---

## Configuration

Edit the top section of the script to change defaults:

**Bash** (`phase1-setup.sh`):
```bash
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KEYCLOAK_URL="http://localhost:8080/admin"
ADMIN_USER="admin"
ADMIN_PASS="admin"
PORT=8080
```

**Python** (`phase1_setup.py`):
```python
PROJECT_DIR = Path(__file__).parent.parent.absolute()
KEYCLOAK_URL = "http://localhost:8080/admin"
ADMIN_USER = "admin"
ADMIN_PASS = "admin"
PORT = 8080
```

---

## What These Scripts Do (Detailed)

### Check Prerequisites

Verifies:
- ✓ Java 17, 21, or 25 is installed
- ✓ Maven 3.6+ is installed
- ✓ At least 5GB disk space available
- ✓ Project directory exists with `pom.xml`

### Free Port 8080

On **Linux/macOS**:
```bash
lsof -t -i :8080 | xargs kill -9
```

On **Windows**:
```cmd
netstat -ano | findstr :8080 | for /f "tokens=5" %a in ('more') do taskkill /PID %a /F
```

### Build

```bash
./mvnw -pl quarkus/server -am -DskipTests clean install
```

**Why `-pl quarkus/server`?**
- Builds ONLY the Quarkus server module (not all 147 modules)
- Skips JS/admin UI build (avoids pnpm symlink issues)
- Faster: ~2-3 minutes instead of 10+ minutes

**Why `-am`?**
- Auto-builds upstream dependencies needed by quarkus/server
- Ensures all required modules are compiled

### Run

```bash
./mvnw -f quarkus/server/pom.xml compile quarkus:dev \
  -Dkc.config.built=true \
  -Dquarkus.args="start-dev --bootstrap-admin-username admin --bootstrap-admin-password admin"
```

**Key Flags:**
- `quarkus:dev` — Starts dev mode with live reload
- `compile` — Ensures code is compiled before starting
- `-Dkc.config.built=true` — Uses pre-built configuration
- `--bootstrap-admin-username admin` — Creates this user
- `--bootstrap-admin-password admin` — Sets this password

---

## Next Steps

After successful build and run:

1. **Access Admin Console:** http://localhost:8080/admin
2. **Login:** `admin` / `admin`
3. **Phase 2:** Create AGM realm with 2 users
4. **Phase 3:** Code customizations (if needed)
5. **Phase 4:** Containerization and deployment

---

## Useful Commands While Running

When Keycloak is running via the scripts, you can:

### In Bash Script
- Press `Ctrl+C` to stop the server

### In Python Script
- Press `Ctrl+C` to stop the server

### Check Process
```bash
ps aux | grep java | grep quarkus
```

### Check Port
```bash
lsof -i :8080
```

### View Logs
The server runs in foreground, so all logs are visible directly in the terminal.

To run in background and capture logs:
```bash
./scripts/phase1-setup.sh run > keycloak.log 2>&1 &
tail -f keycloak.log
```

---

## Environment Requirements

| Tool | Version | Check |
|------|---------|-------|
| Java | 17, 21, or 25 | `java -version` |
| Maven | 3.6+ | `mvn -version` |
| Python (for `.py` script) | 3.6+ | `python3 --version` |
| Bash (for `.sh` script) | Any | Built-in on Linux/macOS |

---

## Script Maintenance

These scripts are self-contained and don't have external dependencies beyond Maven and Java.

To update:
1. Edit the script
2. Keep commands in sync with official Keycloak docs
3. Update configuration section if defaults change
4. Test with: `./scripts/phase1-setup.sh all`

---

## Questions?

For details on what each step does, see:
- `../memory/execution_guide_keycloak_phase1.md` — Detailed guide with troubleshooting
- `../memory/plan_keycloak_build_run.md` — High-level plan
- `../docs/building.md` — Official Keycloak build documentation

