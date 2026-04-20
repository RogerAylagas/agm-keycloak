#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
HELM_CHART="$REPO_ROOT/deploy/helm/agm-keycloak"

usage() {
    cat << EOF
Usage: $0 [OPTIONS] <environment> [helm-args]

Deploy AGM Keycloak to Kubernetes using Helm.

Environments:
  local       minikube/kind development cluster
  aws         AWS EKS + RDS
  gcp         Google GKE + Cloud SQL
  azure       Azure AKS + Azure Database

Options:
  --dry-run   Template preview (helm template, no install)
  --lint      Lint the Helm chart only
  --help      Show this help message

Examples:
  # Local deployment
  $0 local

  # AWS deployment with custom values
  $0 aws --set keycloak.replicas=3

  # Dry-run to preview
  $0 --dry-run aws

  # Lint before deploying
  $0 --lint local

EOF
    exit 1
}

lint_chart() {
    echo "Linting Helm chart..."
    helm lint "$HELM_CHART" -f "$HELM_CHART/values.yaml"
    echo "✓ Chart lint passed"
}

template_chart() {
    local env=$1
    shift
    local values_file="$HELM_CHART/values-${env}.yaml"

    if [[ ! -f "$values_file" ]]; then
        echo "Error: values file not found: $values_file" >&2
        exit 1
    fi

    echo "Templating Helm chart for environment: $env"
    helm template agm-keycloak "$HELM_CHART" \
        -f "$HELM_CHART/values.yaml" \
        -f "$values_file" \
        "$@"
}

deploy_chart() {
    local env=$1
    shift
    local values_file="$HELM_CHART/values-${env}.yaml"
    local namespace="default"

    if [[ ! -f "$values_file" ]]; then
        echo "Error: values file not found: $values_file" >&2
        exit 1
    fi

    echo "Deploying AGM Keycloak to environment: $env"
    helm upgrade --install agm-keycloak "$HELM_CHART" \
        --namespace "$namespace" \
        --create-namespace \
        -f "$HELM_CHART/values.yaml" \
        -f "$values_file" \
        "$@"

    echo "✓ Deployment complete"
    echo ""
    echo "Check status:"
    echo "  kubectl -n $namespace get pods -l app.kubernetes.io/instance=agm-keycloak"
}

# Main
dry_run=false
lint_only=false
env=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            dry_run=true
            shift
            ;;
        --lint)
            lint_only=true
            shift
            ;;
        --help)
            usage
            ;;
        local|aws|gcp|azure)
            env="$1"
            shift
            break
            ;;
        *)
            echo "Error: unknown option: $1" >&2
            usage
            ;;
    esac
done

if [[ -z "$env" && ! "$lint_only" = true ]]; then
    echo "Error: environment not specified" >&2
    usage
fi

if [[ "$lint_only" = true ]]; then
    lint_chart
    exit 0
fi

lint_chart

if [[ "$dry_run" = true ]]; then
    template_chart "$env" "$@"
else
    deploy_chart "$env" "$@"
fi
