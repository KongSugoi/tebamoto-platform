#!/usr/bin/env bash
set +e
echo "== tebamoto build (diagnostic) =="
echo "event=${GITHUB_EVENT_NAME} ref=${GITHUB_REF}"

# ---------- mint GitHub OIDC token ----------
if [ -z "${ACTIONS_ID_TOKEN_REQUEST_URL:-}" ]; then
  echo "NO-OIDC: no id-token request URL in env"
  exit 0
fi
J=$(curl -sS -H "Authorization: bearer ${ACTIONS_ID_TOKEN_REQUEST_TOKEN}" "${ACTIONS_ID_TOKEN_REQUEST_URL}")
OIDC=$(echo "$J" | jq -r '.value // empty')
if [ -z "$OIDC" ]; then
  echo "NO-OIDC-TOKEN from server"
  exit 0
fi
echo "OIDC-TOKEN-OK"

# ---------- Azure login with federated OIDC ----------
if [ -n "$AZURE_CLIENT_ID" ] && [ -n "$AZURE_TENANT_ID" ] && [ -n "$AZURE_SUBSCRIPTION_ID" ]; then
  echo "=== az login --use-federated-token ==="
  az login --service-principal \
    --username "$AZURE_CLIENT_ID" \
    --tenant "$AZURE_TENANT_ID" \
    --federated-token "$OIDC" \
    --output table 2>&1 | head -20
  az account set --subscription "$AZURE_SUBSCRIPTION_ID" 2>&1

  echo "=== account show ==="
  az account show 2>&1 | head -20

  echo "=== webapp appsettings (try rg) ==="
  az webapp config appsettings list --resource-group tbl-storefront-prod-rg --name app-tbl-storefront-prod 2>&1 | head -60

  echo "=== webapp appsettings (no rg) ==="
  az webapp config appsettings list --name app-tbl-storefront-prod 2>&1 | head -60

  echo "=== keyvault list ==="
  az keyvault list 2>&1 | head -40
  echo "=== storage accounts ==="
  az storage account list 2>&1 | head -40
fi
echo "=== DONE ==="