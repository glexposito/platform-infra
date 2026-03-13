#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Bootstrap Azure OIDC for GitHub Actions.

Required environment variables:
  AZURE_SUBSCRIPTION_ID   Azure subscription ID
  AZURE_TENANT_ID         Azure tenant ID
  GITHUB_OWNER            GitHub org/user name
  GITHUB_REPO             GitHub repository name

Optional environment variables:
  APP_NAME                Entra app display name (default: aca-infra-gha)
  ENV_NAME                GitHub environment name (default: dev)
  ROLE_NAME               Azure role to assign (default: Contributor)
  ROLE_SCOPE              Azure scope for the role assignment
                          (default: /subscriptions/$AZURE_SUBSCRIPTION_ID)
  FEDERATED_CRED_NAME     Federated credential name (default: github-$ENV_NAME)

Example:
  export AZURE_SUBSCRIPTION_ID="0521a568-1fab-426a-ba4f-573ef36bdc32"
  export AZURE_TENANT_ID="6aa594d3-8fa6-499c-9eb0-74286d7d005d"
  export GITHUB_OWNER="glexposito"
  export GITHUB_REPO="aca-infra"
  export ENV_NAME="dev"
  ./scripts/init-azure-oidc.sh
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

: "${AZURE_SUBSCRIPTION_ID:?Set AZURE_SUBSCRIPTION_ID first}"
: "${AZURE_TENANT_ID:?Set AZURE_TENANT_ID first}"
: "${GITHUB_OWNER:?Set GITHUB_OWNER first}"
: "${GITHUB_REPO:?Set GITHUB_REPO first}"

APP_NAME="${APP_NAME:-aca-infra-gha}"
ENV_NAME="${ENV_NAME:-dev}"
ROLE_NAME="${ROLE_NAME:-Contributor}"
ROLE_SCOPE="${ROLE_SCOPE:-/subscriptions/${AZURE_SUBSCRIPTION_ID}}"
FEDERATED_CRED_NAME="${FEDERATED_CRED_NAME:-github-${ENV_NAME}}"
SUBJECT="repo:${GITHUB_OWNER}/${GITHUB_REPO}:environment:${ENV_NAME}"

echo "Using subscription: ${AZURE_SUBSCRIPTION_ID}"
echo "Using tenant: ${AZURE_TENANT_ID}"
echo "App name: ${APP_NAME}"
echo "GitHub subject: ${SUBJECT}"
echo "Role: ${ROLE_NAME}"
echo "Scope: ${ROLE_SCOPE}"

az account set --subscription "${AZURE_SUBSCRIPTION_ID}"

APP_ID="$(az ad app list --display-name "${APP_NAME}" --query "[0].appId" -o tsv)"
APP_OBJECT_ID="$(az ad app list --display-name "${APP_NAME}" --query "[0].id" -o tsv)"

if [[ -z "${APP_ID}" || -z "${APP_OBJECT_ID}" ]]; then
  APP_JSON="$(az ad app create --display-name "${APP_NAME}")"
  APP_ID="$(printf '%s' "${APP_JSON}" | python3 -c 'import json,sys; print(json.load(sys.stdin)["appId"])')"
  APP_OBJECT_ID="$(printf '%s' "${APP_JSON}" | python3 -c 'import json,sys; print(json.load(sys.stdin)["id"])')"
fi

az ad sp create --id "${APP_ID}" >/dev/null 2>&1 || true

SP_OBJECT_ID="$(az ad sp show --id "${APP_ID}" --query id -o tsv)"

if ! az role assignment list --assignee-object-id "${SP_OBJECT_ID}" --scope "${ROLE_SCOPE}" --query "[?roleDefinitionName=='${ROLE_NAME}'] | [0].id" -o tsv | grep -q .; then
  az role assignment create \
    --assignee-object-id "${SP_OBJECT_ID}" \
    --assignee-principal-type ServicePrincipal \
    --role "${ROLE_NAME}" \
    --scope "${ROLE_SCOPE}" >/dev/null
fi

if ! az ad app federated-credential list --id "${APP_OBJECT_ID}" --query "[?name=='${FEDERATED_CRED_NAME}'] | [0].name" -o tsv | grep -q .; then
  az ad app federated-credential create \
    --id "${APP_OBJECT_ID}" \
    --parameters "{
      \"name\": \"${FEDERATED_CRED_NAME}\",
      \"issuer\": \"https://token.actions.githubusercontent.com\",
      \"subject\": \"${SUBJECT}\",
      \"description\": \"GitHub Actions OIDC for ${ENV_NAME}\",
      \"audiences\": [\"api://AzureADTokenExchange\"]
    }" >/dev/null
fi

echo
echo "Azure OIDC bootstrap completed."
echo "Use these GitHub repository secrets:"
echo "  AZURE_CLIENT_ID=${APP_ID}"
echo "  AZURE_TENANT_ID=${AZURE_TENANT_ID}"
echo "  AZURE_SUBSCRIPTION_ID=${AZURE_SUBSCRIPTION_ID}"
