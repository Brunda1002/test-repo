#!/usr/bin/env bash
# =============================================================================
# ALB on AKS — One-Time Bootstrap Script
# =============================================================================
# Run this ONCE per account before triggering the GitHub Actions pipeline
# for the first time.
#
# What this script does (and why it can't be in Terraform or the pipeline):
#
#   1. Creates the Terraform state backend (storage account + container).
#      Terraform cannot create its own backend. The pipeline cannot do this
#      because terraform init fails without the backend existing first.
#
# That's it. Everything else (role assignments, ALB association, RBAC wait)
# now lives inside the pipeline as the "rbac" job between Phase 1 and Phase 2,
# so sequencing is guaranteed and you never need to run anything manually
# in parallel with the pipeline again.
#
# Replicating on another account
# ────────────────────────────────
#   1. Edit the CONFIGURATION block below.
#   2. Run: bash setup.sh
#   3. Push to the branch / manually dispatch infra.yml.
#      The pipeline handles everything else automatically.
#
# Prerequisites
#   - Azure CLI logged in as Owner or User Access Administrator
#   - Access to the target subscription
# =============================================================================

set -euo pipefail

# ══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION — edit these values when replicating on another account
# ══════════════════════════════════════════════════════════════════════════════

SUBSCRIPTION_ID="91ea5a42-5e9b-4c0c-a766-ea2a2aaa3ace"
LOCATION="eastus"

# Must match infra/backend.tf
TFSTATE_RESOURCE_GROUP="rg-tfstate"
TFSTATE_STORAGE_ACCOUNT="sttfstateaksalb001"   # globally unique — change when replicating
TFSTATE_CONTAINER="tfstate"

# ══════════════════════════════════════════════════════════════════════════════
# HELPERS
# ══════════════════════════════════════════════════════════════════════════════

info()    { echo "[INFO]  $*"; }
success() { echo "[OK]    $*"; }
die()     { echo "[ERROR] $*" >&2; exit 1; }

require_cmd() {
  command -v "$1" &>/dev/null || die "'$1' is not installed. Please install it and retry."
}

# ══════════════════════════════════════════════════════════════════════════════
# PRE-FLIGHT
# ══════════════════════════════════════════════════════════════════════════════

require_cmd az

info "Setting active subscription to $SUBSCRIPTION_ID ..."
az account set --subscription "$SUBSCRIPTION_ID"
success "Subscription set."

# ══════════════════════════════════════════════════════════════════════════════
# STEP 1 — Terraform state backend
# ══════════════════════════════════════════════════════════════════════════════

echo ""
echo "══════════════════════════════════════════════════════════════════════"
echo " STEP 1: Terraform state backend"
echo "══════════════════════════════════════════════════════════════════════"

# 1a. Resource group
if az group show --name "$TFSTATE_RESOURCE_GROUP" --subscription "$SUBSCRIPTION_ID" &>/dev/null; then
  success "Resource group '$TFSTATE_RESOURCE_GROUP' already exists — skipping."
else
  info "Creating resource group '$TFSTATE_RESOURCE_GROUP' ..."
  az group create \
    --name "$TFSTATE_RESOURCE_GROUP" \
    --location "$LOCATION" \
    --subscription "$SUBSCRIPTION_ID"
  success "Resource group created."
fi

# 1b. Storage account
if az storage account show \
     --name "$TFSTATE_STORAGE_ACCOUNT" \
     --resource-group "$TFSTATE_RESOURCE_GROUP" \
     --subscription "$SUBSCRIPTION_ID" &>/dev/null; then
  success "Storage account '$TFSTATE_STORAGE_ACCOUNT' already exists — skipping."
else
  info "Creating storage account '$TFSTATE_STORAGE_ACCOUNT' ..."
  az storage account create \
    --name "$TFSTATE_STORAGE_ACCOUNT" \
    --resource-group "$TFSTATE_RESOURCE_GROUP" \
    --location "$LOCATION" \
    --sku Standard_LRS \
    --kind StorageV2 \
    --min-tls-version TLS1_2 \
    --allow-blob-public-access false \
    --subscription "$SUBSCRIPTION_ID"
  success "Storage account created."
fi

# 1c. Blob container
STORAGE_KEY=$(az storage account keys list \
  --account-name "$TFSTATE_STORAGE_ACCOUNT" \
  --resource-group "$TFSTATE_RESOURCE_GROUP" \
  --subscription "$SUBSCRIPTION_ID" \
  --query "[0].value" --output tsv)

if az storage container show \
     --name "$TFSTATE_CONTAINER" \
     --account-name "$TFSTATE_STORAGE_ACCOUNT" \
     --account-key "$STORAGE_KEY" &>/dev/null 2>&1; then
  success "Blob container '$TFSTATE_CONTAINER' already exists — skipping."
else
  info "Creating blob container '$TFSTATE_CONTAINER' ..."
  az storage container create \
    --name "$TFSTATE_CONTAINER" \
    --account-name "$TFSTATE_STORAGE_ACCOUNT" \
    --account-key "$STORAGE_KEY" \
    --public-access off
  success "Blob container created."
fi

# ══════════════════════════════════════════════════════════════════════════════
# DONE
# ══════════════════════════════════════════════════════════════════════════════

echo ""
echo "══════════════════════════════════════════════════════════════════════"
echo " SETUP COMPLETE"
echo "══════════════════════════════════════════════════════════════════════"
echo ""
echo "  Terraform backend: $TFSTATE_STORAGE_ACCOUNT / $TFSTATE_CONTAINER"
echo ""
echo "Next step:"
echo "  Trigger the GitHub Actions pipeline (push to main or"
echo "  manually dispatch infra.yml)."
echo ""
echo "  The pipeline will:"
echo "    Phase 1  — create all Azure infrastructure via Terraform"
echo "    rbac job — assign roles + wait 5 min for RBAC propagation"
echo "    Phase 2  — install ALB controller, wait for GatewayClass,"
echo "               then apply Gateway + HTTPRoute"
echo ""
echo "  No other manual steps are needed."
