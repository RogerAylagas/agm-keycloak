#!/bin/bash

################################################################################
# AGM Keycloak - Phase 1 Setup Script
#
# Purpose: Automate building and running Keycloak locally
# Usage: ./scripts/phase1-setup.sh [command]
#   - check-prereqs    : Check if all prerequisites are met
#   - free-port        : Kill any process on port 8080
#   - build            : Build Keycloak Quarkus server
#   - run              : Run Keycloak in dev mode with admin credentials
#   - all              : Execute all steps (default)
#   - verify           : Check if Keycloak is running and accessible
#
# Author: AGM Development
# Date: 2026-04-17
################################################################################

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KEYCLOAK_URL="http://localhost:8080/admin"
ADMIN_USER="admin"
ADMIN_PASS="admin"
PORT=8080

################################################################################
# Utility Functions
################################################################################

print_header() {
    echo -e "\n${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

################################################################################
# Check Prerequisites
################################################################################

check_prereqs() {
    print_header "Checking Prerequisites"

    local errors=0

    # Check Java
    if command -v java &> /dev/null; then
        java_version=$(java -version 2>&1 | grep -oP '(?<=version ")[^"]*')
        if [[ $java_version == *"21"* ]] || [[ $java_version == *"17"* ]] || [[ $java_version == *"25"* ]]; then
            print_success "Java installed: $java_version"
        else
            print_error "Java version must be 17, 21, or 25 (found: $java_version)"
            ((errors++))
        fi
    else
        print_error "Java not found. Install JDK 21+"
        ((errors++))
    fi

    # Check Maven
    if command -v mvn &> /dev/null; then
        mvn_version=$(mvn -v 2>&1 | grep "Apache Maven" | awk '{print $3}')
        print_success "Maven installed: $mvn_version"
    else
        print_error "Maven not found. Install Maven 3.6+"
        ((errors++))
    fi

    # Check disk space
    disk_available=$(df "$PROJECT_DIR" | awk 'NR==2 {print $4}')
    disk_gb=$((disk_available / 1024 / 1024))
    if [ "$disk_gb" -gt 5 ]; then
        print_success "Disk space: $disk_gb GB available"
    else
        print_warning "Low disk space: ${disk_gb}GB available (recommend 5GB+)"
    fi

    # Check project structure
    if [ -f "$PROJECT_DIR/pom.xml" ]; then
        print_success "Project directory: $PROJECT_DIR"
    else
        print_error "Project not found at: $PROJECT_DIR"
        ((errors++))
    fi

    if [ $errors -eq 0 ]; then
        print_success "All prerequisites met!"
        return 0
    else
        print_error "Prerequisites check failed with $errors errors"
        return 1
    fi
}

################################################################################
# Free Port 8080
################################################################################

free_port() {
    print_header "Freeing Port $PORT"

    # Check if port is in use
    if lsof -i ":$PORT" &> /dev/null; then
        print_warning "Port $PORT is in use. Attempting to free it..."

        # Get PIDs using the port
        pids=$(lsof -t -i ":$PORT" 2>/dev/null || true)

        if [ -z "$pids" ]; then
            print_success "Port $PORT is already free"
            return 0
        fi

        print_info "Found processes: $pids"

        # Try to kill processes (may need sudo)
        for pid in $pids; do
            if sudo kill -9 "$pid" 2>/dev/null; then
                print_success "Killed process $pid"
            else
                print_warning "Could not kill process $pid (may need sudo)"
            fi
        done

        # Give it a moment
        sleep 2

        # Verify port is free
        if lsof -i ":$PORT" &> /dev/null; then
            print_error "Port $PORT is still in use. Please stop Traefik or other services."
            return 1
        fi
    fi

    print_success "Port $PORT is free"
    return 0
}

################################################################################
# Build Keycloak
################################################################################

build_keycloak() {
    print_header "Building Keycloak Quarkus Server"

    cd "$PROJECT_DIR"

    print_info "Running Maven build (this takes 2-3 minutes)..."
    print_info "Command: ./mvnw -pl quarkus/server -am -DskipTests clean install"
    echo

    if ./mvnw -pl quarkus/server -am -DskipTests clean install; then
        print_success "Build completed successfully!"
        echo
        print_info "Build artifacts location:"
        echo "  - Server JAR: quarkus/server/target/keycloak-quarkus-server-app-dev.jar"
        return 0
    else
        print_error "Build failed. Check the output above for details."
        return 1
    fi
}

################################################################################
# Run Keycloak
################################################################################

run_keycloak() {
    print_header "Starting Keycloak in Dev Mode"

    cd "$PROJECT_DIR"

    print_info "Admin credentials:"
    echo "  - Username: $ADMIN_USER"
    echo "  - Password: $ADMIN_PASS"
    echo

    print_info "Running Keycloak..."
    print_info "Command:"
    echo "  ./mvnw -f quarkus/server/pom.xml compile quarkus:dev \\"
    echo "    -Dkc.config.built=true \\"
    echo "    -Dquarkus.args=\"start-dev --bootstrap-admin-username $ADMIN_USER --bootstrap-admin-password $ADMIN_PASS\""
    echo

    print_warning "Keycloak is starting. Once you see 'Listening on: http://localhost:8080', it's ready!"
    echo

    # Start Keycloak in foreground so user can see output
    ./mvnw -f quarkus/server/pom.xml compile quarkus:dev \
        -Dkc.config.built=true \
        -Dquarkus.args="start-dev --bootstrap-admin-username $ADMIN_USER --bootstrap-admin-password $ADMIN_PASS"
}

################################################################################
# Verify Installation
################################################################################

verify_keycloak() {
    print_header "Verifying Keycloak Installation"

    print_info "Checking if Keycloak is running on $KEYCLOAK_URL..."

    # Check if process is running
    if ps aux | grep -i "start-dev" | grep -v grep &> /dev/null; then
        print_success "Keycloak process is running"
    else
        print_warning "Keycloak process not detected"
        return 1
    fi

    # Check if port is listening
    if lsof -i ":$PORT" &> /dev/null; then
        print_success "Port $PORT is listening"
    else
        print_error "Port $PORT is not listening"
        return 1
    fi

    # Try to reach admin console
    print_info "Attempting to reach admin console..."

    if curl -s -f "$KEYCLOAK_URL" &> /dev/null; then
        print_success "Admin console is accessible at $KEYCLOAK_URL"
    else
        print_warning "Admin console not yet responding (server may still be starting)"
        print_info "Try accessing http://localhost:8080/admin in your browser in 10-30 seconds"
        return 0
    fi

    echo
    print_success "Keycloak is running and accessible!"
    echo
    print_info "Access the admin console at:"
    echo "  ${BLUE}http://localhost:8080/admin${NC}"
    echo
    print_info "Login with:"
    echo "  Username: $ADMIN_USER"
    echo "  Password: $ADMIN_PASS"

    return 0
}

################################################################################
# Main Function
################################################################################

main() {
    local command="${1:-all}"

    case "$command" in
        check-prereqs|check)
            check_prereqs
            ;;
        free-port|free)
            free_port
            ;;
        build)
            check_prereqs || exit 1
            free_port || exit 1
            build_keycloak
            ;;
        run|start)
            run_keycloak
            ;;
        all|full)
            check_prereqs || exit 1
            free_port || exit 1
            build_keycloak || exit 1
            echo
            print_warning "Build complete! Ready to start Keycloak?"
            echo "Press Enter to continue or Ctrl+C to exit..."
            read -r
            run_keycloak
            ;;
        verify)
            verify_keycloak
            ;;
        help|--help|-h)
            cat << EOF
AGM Keycloak Phase 1 Setup Script

Usage: $0 [command]

Commands:
  check-prereqs    Check if all prerequisites are met
  free-port        Kill any process on port 8080
  build            Build Keycloak Quarkus server (44 modules, ~2-3 min)
  run              Start Keycloak in dev mode (runs in foreground)
  all              Execute all steps: check → free → build → run (default)
  verify           Verify Keycloak is running and accessible
  help             Show this help message

Examples:
  # Full setup from scratch
  $0 all

  # Just free the port
  $0 free-port

  # Just build
  $0 build

  # Start Keycloak (assumes already built)
  $0 run

Environment:
  Project Directory: $PROJECT_DIR
  Keycloak URL:      $KEYCLOAK_URL
  Admin User:        $ADMIN_USER
  Admin Password:    $ADMIN_PASS

EOF
            ;;
        *)
            print_error "Unknown command: $command"
            echo "Run '$0 help' for usage information"
            exit 1
            ;;
    esac
}

# Run main function with arguments
main "$@"
