#!/usr/bin/env bash
# setup.sh — Run ONCE after Stage 1 (terraform apply) completes.
# Assigns the two RBAC roles the ALB managed identity needs before Stage 2.
# Run as: bash setup.sh

set -euo pipefail

# ── Variables (must match terraform.tfvars / main.tf) ─────────────────────
SUBSCRIPTION_ID="91ea5a42-5e9b-4c0c-a766-ea2a2aaa3ace"
RESOURCE_GROUP="Grouper-Dev"
NAME_PREFIX="grouper-dev"
ALB_NAME="alb-${NAME_PREFIX}"           # azapi_resource.alb → name = "alb-grouper-dev"
IDENTITY_NAME="mi-alb-${NAME_PREFIX}"   # azurerm_user_assigned_identity.alb → name = "mi-alb-grouper-dev"

echo "── Setting subscription"
az account set --subscription "$SUBSCRIPTION_ID"
echo "[OK]    Subscription set to: $SUBSCRIPTION_ID"

echo "── Getting ALB identity principal ID"
ALB_PRINCIPAL_ID=$(az identity show \
  --name "$IDENTITY_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query principalId -o tsv)
echo "[OK]    ALB identity principal: $ALB_PRINCIPAL_ID"

echo "── Getting ALB resource ID"
ALB_RESOURCE_ID=$(az resource show \
  --resource-group "$RESOURCE_GROUP" \
  --resource-type "Microsoft.ServiceNetworking/trafficControllers" \
  --name "$ALB_NAME" \
  --query id -o tsv)
echo "[OK]    ALB resource ID: $ALB_RESOURCE_ID"

echo "── Assigning roles"

# 1. Reader on the ALB resource
az role assignment create \
  --assignee-object-id "$ALB_PRINCIPAL_ID" \
  --assignee-principal-type ServicePrincipal \
  --role "Reader" \
  --scope "$ALB_RESOURCE_ID"
echo "[OK]    Reader on ALB resource — assigned."

# 2. Network Contributor on the resource group
az role assignment create \
  --assignee-object-id "$ALB_PRINCIPAL_ID" \
  --assignee-principal-type ServicePrincipal \
  --role "Network Contributor" \
  --scope "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}"
echo "[OK]    Network Contributor on resource group — assigned."

echo "── Waiting 5 min for RBAC to propagate..."
for i in $(seq 30 30 300); do
  sleep 30
  echo "[INFO]    ${i}s elapsed"
done

echo "[OK]    Done. Now trigger Stage 2:"
echo "   GitHub Actions → Run workflow (workflow_dispatch) → set run_stage2=yes → Run workflow"