#!/usr/bin/env python3

"""
AGM Keycloak - Phase 1 Setup Script (Python Version)

Purpose: Automate building and running Keycloak locally (cross-platform)
Usage: python3 phase1_setup.py [command]

Commands:
  check-prereqs    Check if all prerequisites are met
  free-port        Kill any process on port 8080
  build            Build Keycloak Quarkus server
  run              Run Keycloak in dev mode with admin credentials
  all              Execute all steps (default)
  verify           Check if Keycloak is running and accessible
"""

import os
import sys
import subprocess
import shutil
import json
from pathlib import Path
from typing import Tuple, Optional
import socket
import time
import urllib.request
import urllib.error

# Color codes
class Colors:
    HEADER = '\033[94m'
    SUCCESS = '\033[92m'
    WARNING = '\033[93m'
    ERROR = '\033[91m'
    INFO = '\033[94m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'

# Configuration
PROJECT_DIR = Path(__file__).parent.parent.absolute()
KEYCLOAK_URL = "http://localhost:8080/admin"
ADMIN_USER = "admin"
ADMIN_PASS = "admin"
PORT = 8080

# ============================================================================
# Utility Functions
# ============================================================================

def print_header(text: str) -> None:
    """Print a formatted header."""
    print()
    print(f"{Colors.HEADER}{'═' * 60}{Colors.ENDC}")
    print(f"{Colors.HEADER}{text}{Colors.ENDC}")
    print(f"{Colors.HEADER}{'═' * 60}{Colors.ENDC}")
    print()

def print_success(text: str) -> None:
    """Print a success message."""
    print(f"{Colors.SUCCESS}✓ {text}{Colors.ENDC}")

def print_error(text: str) -> None:
    """Print an error message."""
    print(f"{Colors.ERROR}✗ {text}{Colors.ENDC}")

def print_warning(text: str) -> None:
    """Print a warning message."""
    print(f"{Colors.WARNING}⚠ {text}{Colors.ENDC}")

def print_info(text: str) -> None:
    """Print an info message."""
    print(f"{Colors.INFO}ℹ {text}{Colors.ENDC}")

def run_command(cmd: list, description: str = "") -> Tuple[int, str]:
    """
    Run a shell command and return exit code and output.

    Args:
        cmd: Command as list of strings
        description: Optional description to print

    Returns:
        Tuple of (return_code, combined_output)
    """
    if description:
        print_info(description)

    try:
        result = subprocess.run(
            cmd,
            capture_output=False,
            text=True,
            cwd=str(PROJECT_DIR)
        )
        return result.returncode, ""
    except Exception as e:
        return 1, str(e)

def is_command_available(cmd: str) -> bool:
    """Check if a command is available in PATH."""
    return shutil.which(cmd) is not None

def get_command_version(cmd: str, version_flag: str = "-version") -> Optional[str]:
    """Get the version of a command."""
    try:
        result = subprocess.run(
            [cmd, version_flag],
            capture_output=True,
            text=True,
            timeout=5
        )
        return result.stdout + result.stderr
    except Exception:
        return None

def is_port_in_use(port: int) -> bool:
    """Check if a port is in use."""
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    result = sock.connect_ex(('127.0.0.1', port))
    sock.close()
    return result == 0

def get_java_version() -> Optional[str]:
    """Get installed Java version."""
    output = get_command_version("java")
    if output and "version" in output.lower():
        # Extract version number
        for line in output.split('\n'):
            if 'version' in line.lower():
                return line.strip()
    return None

def get_disk_space(path: str) -> int:
    """Get available disk space in GB."""
    try:
        if sys.platform == "win32":
            import ctypes
            free_bytes = ctypes.c_ulonglong(0)
            ctypes.windll.kernel32.GetDiskFreeSpaceExW(
                ctypes.c_wchar_p(path),
                None,
                None,
                ctypes.pointer(free_bytes)
            )
            return free_bytes.value // (1024 ** 3)
        else:
            stat = os.statvfs(path)
            return (stat.f_bavail * stat.f_frsize) // (1024 ** 3)
    except Exception:
        return 0

# ============================================================================
# Command Implementations
# ============================================================================

def check_prereqs() -> bool:
    """Check if all prerequisites are installed."""
    print_header("Checking Prerequisites")

    errors = 0

    # Check Java
    if is_command_available("java"):
        java_version = get_java_version()
        if any(v in (java_version or "") for v in ["21", "17", "25"]):
            print_success(f"Java installed: {java_version.split('(')[0].strip()}")
        else:
            print_error(f"Java version must be 17, 21, or 25 (found: {java_version})")
            errors += 1
    else:
        print_error("Java not found. Install JDK 21+")
        errors += 1

    # Check Maven
    if is_command_available("mvn"):
        mvn_version = get_command_version("mvn")
        if mvn_version and "Apache Maven" in mvn_version:
            version_line = [l for l in mvn_version.split('\n') if "Apache Maven" in l][0]
            print_success(f"Maven installed: {version_line.strip()}")
        else:
            print_success("Maven installed")
    else:
        print_error("Maven not found. Install Maven 3.6+")
        errors += 1

    # Check disk space
    disk_gb = get_disk_space(str(PROJECT_DIR))
    if disk_gb >= 5:
        print_success(f"Disk space: {disk_gb} GB available")
    elif disk_gb > 0:
        print_warning(f"Low disk space: {disk_gb}GB available (recommend 5GB+)")
    else:
        print_warning("Could not determine disk space")

    # Check project structure
    pom_path = PROJECT_DIR / "pom.xml"
    if pom_path.exists():
        print_success(f"Project directory: {PROJECT_DIR}")
    else:
        print_error(f"Project not found at: {PROJECT_DIR}")
        errors += 1

    if errors == 0:
        print_success("All prerequisites met!")
        return True
    else:
        print_error(f"Prerequisites check failed with {errors} errors")
        return False

def free_port() -> bool:
    """Free port 8080 by killing processes using it."""
    print_header(f"Freeing Port {PORT}")

    if not is_port_in_use(PORT):
        print_success(f"Port {PORT} is already free")
        return True

    print_warning(f"Port {PORT} is in use. Attempting to free it...")

    if sys.platform == "win32":
        # Windows: use netstat and taskkill
        try:
            result = subprocess.run(
                f'netstat -ano | findstr :{PORT}',
                shell=True,
                capture_output=True,
                text=True
            )
            pids = set()
            for line in result.stdout.split('\n'):
                parts = line.split()
                if parts:
                    pids.add(parts[-1])

            for pid in pids:
                if pid.isdigit():
                    subprocess.run(f'taskkill /PID {pid} /F', shell=True)
                    print_success(f"Killed process {pid}")
        except Exception as e:
            print_warning(f"Could not kill processes: {e}")
            return False
    else:
        # Unix/Linux: use lsof
        try:
            result = subprocess.run(
                f'lsof -t -i :{PORT}',
                shell=True,
                capture_output=True,
                text=True
            )
            pids = result.stdout.strip().split('\n')

            for pid in pids:
                if pid.isdigit():
                    os.system(f'kill -9 {pid}')
                    print_success(f"Killed process {pid}")
        except Exception as e:
            print_warning(f"Could not kill processes: {e}")
            return False

    time.sleep(2)

    if is_port_in_use(PORT):
        print_error(f"Port {PORT} is still in use. Please stop Traefik or other services manually.")
        return False

    print_success(f"Port {PORT} is now free")
    return True

def build_keycloak() -> bool:
    """Build Keycloak Quarkus server."""
    print_header("Building Keycloak Quarkus Server")

    print_info("Building (this takes 2-3 minutes)...")
    print_info("Command: ./mvnw -pl quarkus/server -am -DskipTests clean install")
    print()

    os.chdir(str(PROJECT_DIR))

    mvn_cmd = "mvnw.cmd" if sys.platform == "win32" else "./mvnw"
    cmd = [
        mvn_cmd,
        "-pl", "quarkus/server",
        "-am",
        "-DskipTests",
        "clean",
        "install"
    ]

    returncode, _ = run_command(cmd)

    if returncode == 0:
        print()
        print_success("Build completed successfully!")
        print()
        print_info("Build artifacts location:")
        print("  - Server JAR: quarkus/server/target/keycloak-quarkus-server-app-dev.jar")
        return True
    else:
        print()
        print_error("Build failed. Check the output above for details.")
        return False

def run_keycloak() -> bool:
    """Run Keycloak in dev mode."""
    print_header("Starting Keycloak in Dev Mode")

    print_info("Admin credentials:")
    print(f"  - Username: {ADMIN_USER}")
    print(f"  - Password: {ADMIN_PASS}")
    print()

    print_info("Starting Keycloak...")
    print("  Command:")
    print("    ./mvnw -f quarkus/server/pom.xml compile quarkus:dev \\")
    print("      -Dkc.config.built=true \\")
    print(f"      -Dquarkus.args=\"start-dev --bootstrap-admin-username {ADMIN_USER} --bootstrap-admin-password {ADMIN_PASS}\"")
    print()

    print_warning("Keycloak is starting. Once you see 'Listening on: http://localhost:8080', it's ready!")
    print()

    os.chdir(str(PROJECT_DIR))

    mvn_cmd = "mvnw.cmd" if sys.platform == "win32" else "./mvnw"
    cmd = [
        mvn_cmd,
        "-f", "quarkus/server/pom.xml",
        "compile",
        "quarkus:dev",
        "-Dkc.config.built=true",
        f"-Dquarkus.args=start-dev --bootstrap-admin-username {ADMIN_USER} --bootstrap-admin-password {ADMIN_PASS}"
    ]

    returncode, _ = run_command(cmd)
    return returncode == 0

def verify_keycloak() -> bool:
    """Verify Keycloak is running and accessible."""
    print_header("Verifying Keycloak Installation")

    print_info(f"Checking if Keycloak is running on {KEYCLOAK_URL}...")

    # Check if port is listening
    if is_port_in_use(PORT):
        print_success(f"Port {PORT} is listening")
    else:
        print_error(f"Port {PORT} is not listening")
        return False

    # Try to reach admin console
    print_info("Attempting to reach admin console...")

    try:
        response = urllib.request.urlopen(KEYCLOAK_URL, timeout=5)
        if response.status == 200:
            print_success("Admin console is accessible")
    except urllib.error.HTTPError:
        print_warning("Admin console not yet responding (server may still be starting)")
        print_info("Try accessing http://localhost:8080/admin in your browser in 10-30 seconds")
        return True
    except Exception as e:
        print_warning(f"Could not reach admin console: {e}")
        print_info("Try accessing http://localhost:8080/admin in your browser")
        return True

    print()
    print_success("Keycloak is running and accessible!")
    print()
    print_info("Access the admin console at:")
    print(f"  {Colors.BOLD}http://localhost:8080/admin{Colors.ENDC}")
    print()
    print_info("Login with:")
    print(f"  Username: {ADMIN_USER}")
    print(f"  Password: {ADMIN_PASS}")

    return True

# ============================================================================
# Main
# ============================================================================

def show_help() -> None:
    """Show help message."""
    help_text = f"""
{Colors.BOLD}AGM Keycloak Phase 1 Setup Script (Python){Colors.ENDC}

{Colors.BOLD}Usage:{Colors.ENDC}
  python3 phase1_setup.py [command]

{Colors.BOLD}Commands:{Colors.ENDC}
  check-prereqs    Check if all prerequisites are met
  free-port        Kill any process on port 8080
  build            Build Keycloak Quarkus server (44 modules, ~2-3 min)
  run              Start Keycloak in dev mode (runs in foreground)
  all              Execute all steps: check → free → build → run (default)
  verify           Verify Keycloak is running and accessible
  help             Show this help message

{Colors.BOLD}Examples:{Colors.ENDC}
  # Full setup from scratch
  python3 phase1_setup.py all

  # Just free the port
  python3 phase1_setup.py free-port

  # Just build
  python3 phase1_setup.py build

  # Start Keycloak (assumes already built)
  python3 phase1_setup.py run

{Colors.BOLD}Environment:{Colors.ENDC}
  Project Directory: {PROJECT_DIR}
  Keycloak URL:      {KEYCLOAK_URL}
  Admin User:        {ADMIN_USER}
  Admin Password:    {ADMIN_PASS}
"""
    print(help_text)

def main() -> int:
    """Main entry point."""
    command = sys.argv[1] if len(sys.argv) > 1 else "all"

    try:
        if command in ["check-prereqs", "check"]:
            return 0 if check_prereqs() else 1

        elif command in ["free-port", "free"]:
            return 0 if free_port() else 1

        elif command == "build":
            if not check_prereqs():
                return 1
            if not free_port():
                return 1
            return 0 if build_keycloak() else 1

        elif command in ["run", "start"]:
            return 0 if run_keycloak() else 1

        elif command in ["all", "full"]:
            if not check_prereqs():
                return 1
            if not free_port():
                return 1
            if not build_keycloak():
                return 1

            print()
            print_warning("Build complete! Ready to start Keycloak?")
            print("Press Enter to continue or Ctrl+C to exit...")
            try:
                input()
            except KeyboardInterrupt:
                return 0

            return 0 if run_keycloak() else 1

        elif command == "verify":
            return 0 if verify_keycloak() else 1

        elif command in ["help", "--help", "-h"]:
            show_help()
            return 0

        else:
            print_error(f"Unknown command: {command}")
            print(f"Run '{sys.argv[0]} help' for usage information")
            return 1

    except KeyboardInterrupt:
        print()
        print_warning("Interrupted by user")
        return 130
    except Exception as e:
        print()
        print_error(f"Unexpected error: {e}")
        return 1

if __name__ == "__main__":
    sys.exit(main())
