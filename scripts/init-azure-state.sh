#!/usr/bin/env bash
# #az provider register --namespace Microsoft.Storage
# az provider register --namespace Microsoft.App
# Not needed in real life... it should be there

set -euo pipefail

usage() {
  cat <<'EOF'
Bootstrap the Azure Storage backend used by Terragrunt/Terraform.

Required environment variables:
  AZURE_SUBSCRIPTION_ID   Azure subscription ID to target
  STATE_SA                Globally unique Azure Storage Account name

Optional environment variables:
  LOCATION                Azure region (default: southeastasia)
  STATE_RG                Resource group for backend resources (default: rg-aca-terraform-state)
  STATE_CONTAINER         Blob container for tfstate (default: tfstate)

Example:
  export AZURE_SUBSCRIPTION_ID="0521a568-1fab-426a-ba4f-573ef36bdc32"
  export STATE_SA="glexpositotfstate01"
  ./scripts/init-azure-state.sh
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

: "${AZURE_SUBSCRIPTION_ID:?Set AZURE_SUBSCRIPTION_ID first}"
: "${STATE_SA:?Set STATE_SA first}"

LOCATION="${LOCATION:-southeastasia}"
STATE_RG="${STATE_RG:-rg-aca-terraform-state}"
STATE_CONTAINER="${STATE_CONTAINER:-tfstate}"

echo "Using subscription: ${AZURE_SUBSCRIPTION_ID}"
echo "Backend resource group: ${STATE_RG}"
echo "Backend storage account: ${STATE_SA}"
echo "Backend container: ${STATE_CONTAINER}"
echo "Location: ${LOCATION}"

az account set --subscription "${AZURE_SUBSCRIPTION_ID}"

az group create \
  --subscription "${AZURE_SUBSCRIPTION_ID}" \
  --name "${STATE_RG}" \
  --location "${LOCATION}"

az storage account create \
  --subscription "${AZURE_SUBSCRIPTION_ID}" \
  --name "${STATE_SA}" \
  --resource-group "${STATE_RG}" \
  --location "${LOCATION}" \
  --sku Standard_LRS \
  --kind StorageV2 \
  --min-tls-version TLS1_2

az storage container create \
  --subscription "${AZURE_SUBSCRIPTION_ID}" \
  --name "${STATE_CONTAINER}" \
  --account-name "${STATE_SA}" \
  --auth-mode login

echo
echo "State backend created."
echo "Use these values in GitHub secrets:"
echo "  AZURE_SUBSCRIPTION_ID=${AZURE_SUBSCRIPTION_ID}"
echo "  TG_STATE_RESOURCE_GROUP=${STATE_RG}"
echo "  TG_STATE_STORAGE_ACCOUNT=${STATE_SA}"
echo "  TG_STATE_CONTAINER=${STATE_CONTAINER}"
