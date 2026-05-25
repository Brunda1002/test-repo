#!/usr/bin/env bash
# =============================================================================
# One-time setup — run ONCE per account before triggering the pipeline.
# Handles what the deploying SP cannot do (ABAC blocks role assignments):
#   1. Terraform state backend
#   2. ALB subnet association
#   3. Role assignments + RBAC propagation wait
# =============================================================================

set -euo pipefail

# ── Edit these for a new account ─────────────────────────────────────────────
SUBSCRIPTION_ID="91ea5a42-5e9b-4c0c-a766-ea2a2aaa3ace"
LOCATION="eastus"
RESOURCE_GROUP="rg-aks-alb-poc1"
ALB_NAME="alb-poc"
ALB_ASSOCIATION_NAME="alb-association"
ALB_SUBNET_NAME="alb-subnet"
VNET_NAME="vnet-aks-alb-poc1"
PRINCIPAL_ID="f88f890f-d062-4768-9500-379b1f879db2"   # ALB controller managed identity principal ID
TFSTATE_RESOURCE_GROUP="rg-tfstate"
TFSTATE_STORAGE_ACCOUNT="sttfstateaksalb001"           # must be globally unique
TFSTATE_CONTAINER="tfstate"
# ─────────────────────────────────────────────────────────────────────────────

info()    { echo "[INFO]  $*"; }
ok()      { echo "[OK]    $*"; }
die()     { echo "[ERROR] $*" >&2; exit 1; }

az account set --subscription "$SUBSCRIPTION_ID"
ok "Subscription set."

# ── Step 1: Terraform state backend ──────────────────────────────────────────
echo -e "\n── Step 1: Terraform state backend"

if ! az group show --name "$TFSTATE_RESOURCE_GROUP" --subscription "$SUBSCRIPTION_ID" &>/dev/null; then
  az group create --name "$TFSTATE_RESOURCE_GROUP" --location "$LOCATION" --subscription "$SUBSCRIPTION_ID"
fi
ok "Resource group: $TFSTATE_RESOURCE_GROUP"

if ! az storage account show --name "$TFSTATE_STORAGE_ACCOUNT" --resource-group "$TFSTATE_RESOURCE_GROUP" --subscription "$SUBSCRIPTION_ID" &>/dev/null; then
  az storage account create \
    --name "$TFSTATE_STORAGE_ACCOUNT" --resource-group "$TFSTATE_RESOURCE_GROUP" \
    --location "$LOCATION" --sku Standard_LRS --kind StorageV2 \
    --min-tls-version TLS1_2 --allow-blob-public-access false \
    --subscription "$SUBSCRIPTION_ID"
fi
ok "Storage account: $TFSTATE_STORAGE_ACCOUNT"

STORAGE_KEY=$(az storage account keys list \
  --account-name "$TFSTATE_STORAGE_ACCOUNT" --resource-group "$TFSTATE_RESOURCE_GROUP" \
  --subscription "$SUBSCRIPTION_ID" --query "[0].value" --output tsv)

if ! az storage container show --name "$TFSTATE_CONTAINER" \
    --account-name "$TFSTATE_STORAGE_ACCOUNT" --account-key "$STORAGE_KEY" &>/dev/null 2>&1; then
  az storage container create --name "$TFSTATE_CONTAINER" \
    --account-name "$TFSTATE_STORAGE_ACCOUNT" --account-key "$STORAGE_KEY" --public-access off
fi
ok "Blob container: $TFSTATE_CONTAINER"

# ── Step 2: ALB subnet association ───────────────────────────────────────────
echo -e "\n── Step 2: ALB subnet association"

ALB_RESOURCE_ID=$(az resource show \
  --resource-group "$RESOURCE_GROUP" --name "$ALB_NAME" \
  --resource-type "Microsoft.ServiceNetworking/trafficControllers" \
  --subscription "$SUBSCRIPTION_ID" --query id --output tsv)

ALB_SUBNET_ID=$(az network vnet subnet show \
  --resource-group "$RESOURCE_GROUP" --vnet-name "$VNET_NAME" --name "$ALB_SUBNET_NAME" \
  --subscription "$SUBSCRIPTION_ID" --query id --output tsv)

ASSOCIATION_ID="${ALB_RESOURCE_ID}/associations/${ALB_ASSOCIATION_NAME}"

ASSOC_STATE=$(az rest --method GET \
  --url "https://management.azure.com${ASSOCIATION_ID}?api-version=2024-05-01-preview" \
  --output json 2>/dev/null | jq -r '.properties.provisioningState // empty' || echo "")

if [[ "$ASSOC_STATE" == "Succeeded" ]]; then
  ok "ALB association already exists — skipping."
else
  info "Creating ALB association..."
  az rest --method PUT \
    --url "https://management.azure.com${ASSOCIATION_ID}?api-version=2024-05-01-preview" \
    --body "{\"location\":\"${LOCATION}\",\"properties\":{\"associationType\":\"subnets\",\"subnet\":{\"id\":\"${ALB_SUBNET_ID}\"}}}"

  for i in $(seq 1 24); do
    sleep 10
    STATE=$(az rest --method GET \
      --url "https://management.azure.com${ASSOCIATION_ID}?api-version=2024-05-01-preview" \
      --output json | jq -r '.properties.provisioningState')
    info "  ${i}0s — $STATE"
    [[ "$STATE" == "Succeeded" ]] && break
    [[ "$STATE" == "Failed" ]]    && die "Association failed."
  done
  ok "ALB association created."
fi

echo ""
echo "  Import command (run from infra/ directory if first time):"
echo "    terraform import azapi_resource.alb_association \\"
echo "      ${ASSOCIATION_ID}"

# ── Step 3: Role assignments ──────────────────────────────────────────────────
echo -e "\n── Step 3: Role assignments"

assign_role() {
  local ROLE="$1" SCOPE="$2" LABEL="$3"
  EXISTING=$(az role assignment list --assignee "$PRINCIPAL_ID" --role "$ROLE" \
    --scope "$SCOPE" --subscription "$SUBSCRIPTION_ID" --query "length(@)" --output tsv 2>/dev/null || echo "0")
  if [[ "$EXISTING" -gt 0 ]]; then
    ok "$ROLE on $LABEL already assigned."
  else
    az role assignment create --assignee-object-id "$PRINCIPAL_ID" \
      --assignee-principal-type ServicePrincipal --role "$ROLE" \
      --scope "$SCOPE" --subscription "$SUBSCRIPTION_ID"
    ok "$ROLE on $LABEL assigned."
  fi
}

RESOURCE_GROUP_ID="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}"
assign_role "Reader" "$ALB_RESOURCE_ID" "ALB resource"
assign_role "Network Contributor" "$RESOURCE_GROUP_ID" "resource group"

echo -e "\n── Step 4: Waiting 300s for RBAC to propagate..."
for i in $(seq 1 10); do sleep 30; info "  $((i*30))s elapsed"; done
ok "RBAC propagation complete."

echo -e "\n✓ Setup complete. Trigger the pipeline."
