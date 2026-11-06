#!/usr/bin/env bash
# One-time setup, run by a human with Owner on the subscription (az login first).
# Creates: remote state storage (Entra ID auth only), and two GitHub OIDC identities:
#   - plan  identity: Reader + state access, trusted only from the 'dev-plan' environment
#   - apply identity: deploy rights, trusted only from the 'dev' environment (with required reviewers)
# No client secrets are created. Usage:
#   ./bootstrap/bootstrap.sh <github-owner/repo> [location]
set -euo pipefail

REPO="${1:?usage: bootstrap.sh <github-owner/repo> [location]}"
LOCATION="${2:-uksouth}"
SUB_ID="$(az account show --query id -o tsv)"
TENANT_ID="$(az account show --query tenantId -o tsv)"
SUFFIX="$(echo -n "$SUB_ID" | sha1sum | cut -c1-6)"
STATE_RG="rg-tfstate"
STATE_SA="sttfstate${SUFFIX}"

echo "Subscription: $SUB_ID  Repo: $REPO  Region: $LOCATION"

# ---- Remote state ----
az group create -n "$STATE_RG" -l "$LOCATION" \
  --tags owner="$(az account show --query user.name -o tsv)" environment=shared cost-centre=portfolio >/dev/null
az storage account create -n "$STATE_SA" -g "$STATE_RG" -l "$LOCATION" \
  --sku Standard_GRS --kind StorageV2 --min-tls-version TLS1_2 \
  --allow-blob-public-access false --allow-shared-key-access false \
  --https-only true >/dev/null
az storage account blob-service-properties update -n "$STATE_SA" -g "$STATE_RG" \
  --enable-versioning true --enable-delete-retention true --delete-retention-days 14 >/dev/null
SA_ID="$(az storage account show -n "$STATE_SA" -g "$STATE_RG" --query id -o tsv)"
ME="$(az ad signed-in-user show --query id -o tsv)"
az role assignment create --assignee "$ME" --role "Storage Blob Data Contributor" --scope "$SA_ID" >/dev/null
sleep 30 # role propagation
az storage container create -n tfstate --account-name "$STATE_SA" --auth-mode login >/dev/null

make_identity () {
  local name="$1" env="$2"
  local app_id
  app_id="$(az ad app create --display-name "$name" --query appId -o tsv)"
  az ad sp create --id "$app_id" >/dev/null
  az ad app federated-credential create --id "$app_id" --parameters "{
    \"name\": \"github-${env}\",
    \"issuer\": \"https://token.actions.githubusercontent.com\",
    \"subject\": \"repo:${REPO}:environment:${env}\",
    \"audiences\": [\"api://AzureADTokenExchange\"]
  }" >/dev/null
  echo "$app_id"
}

PLAN_ID="$(make_identity "gh-landing-zone-plan" "dev-plan")"
APPLY_ID="$(make_identity "gh-landing-zone-apply" "dev")"
sleep 20

# Plan: read-only on the subscription, read/write on state (for the lock).
az role assignment create --assignee "$PLAN_ID" --role "Reader" --scope "/subscriptions/$SUB_ID" >/dev/null
az role assignment create --assignee "$PLAN_ID" --role "Storage Blob Data Contributor" --scope "$SA_ID" >/dev/null

# Apply: deploy resources and policy, and grant only the Key Vault Administrator role (ABAC condition).
az role assignment create --assignee "$APPLY_ID" --role "Contributor" --scope "/subscriptions/$SUB_ID" >/dev/null
az role assignment create --assignee "$APPLY_ID" --role "Resource Policy Contributor" --scope "/subscriptions/$SUB_ID" >/dev/null
az role assignment create --assignee "$APPLY_ID" --role "Storage Blob Data Contributor" --scope "$SA_ID" >/dev/null
KV_ADMIN_ROLE="00482a5a-887f-4fb3-b363-3b7fe8e74483"
az role assignment create --assignee "$APPLY_ID" --role "Role Based Access Control Administrator" \
  --scope "/subscriptions/$SUB_ID" \
  --condition "((!(ActionMatches{'Microsoft.Authorization/roleAssignments/write'})) OR (@Request[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {${KV_ADMIN_ROLE}})) AND ((!(ActionMatches{'Microsoft.Authorization/roleAssignments/delete'})) OR (@Resource[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {${KV_ADMIN_ROLE}}))" \
  --condition-version "2.0" >/dev/null

cat <<OUT

Done. Add these as GitHub repository *variables* (Settings > Secrets and variables > Actions > Variables).
None of them are secrets.

  AZURE_TENANT_ID        = $TENANT_ID
  AZURE_SUBSCRIPTION_ID  = $SUB_ID
  AZURE_PLAN_CLIENT_ID   = $PLAN_ID
  AZURE_CLIENT_ID        = $APPLY_ID
  TFSTATE_RG             = $STATE_RG
  TFSTATE_ACCOUNT        = $STATE_SA
  LZ_OWNER               = <your email>

Then create two environments: 'dev-plan' (no reviewers) and 'dev' (add yourself as a required reviewer).
OUT
