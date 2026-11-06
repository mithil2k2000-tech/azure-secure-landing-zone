# Deploying

## Prerequisites
- An Azure subscription where you are Owner (a free account works).
- Azure CLI, logged in with `az login`.
- A GitHub repository containing this code.

## 1. Bootstrap (once)
```bash
./bootstrap/bootstrap.sh <github-owner>/<repo> uksouth
```
This creates:
- the state resource group, storage account and container;
- the two Entra applications with OIDC federated credentials;
- their role assignments.

It prints the GitHub variables to add. None of them are secrets.

## 2. GitHub settings
- **Settings > Secrets and variables > Actions > Variables:** add each value the script printed, plus `LZ_OWNER`.
- **Settings > Environments:**
  - create `dev-plan` with no protection;
  - create `dev` with yourself as a required reviewer, restricted to the `main` branch.
- **Settings > Code security:** enable code scanning so the Checkov and Trivy SARIF results appear.

The federated credentials trust the `dev` and `dev-plan` environments only. If a pull request plan fails to authenticate, check that the plan job is using `environment: dev-plan`.

## 3. Plan
Open a pull request. CI runs every gate and posts the plan to the run summary.

## 4. Apply
Merge to `main`, then go to **Actions > Deploy > Run workflow** and type `apply`. Approve the `dev` environment when asked. The job applies exactly the plan it just showed.

For a first deployment, consider `policy_enforce = false`. Check compliance in the portal, then switch enforcement on.

## 5. Tear down
Go to **Actions > Destroy** and type `destroy`. The state storage and identities from bootstrap stay. Delete those by hand if you're finished:
```bash
az group delete -n rg-tfstate
az ad app delete --id <plan-app-id>
az ad app delete --id <apply-app-id>
```

## Local runs
```bash
cd environments/dev
cp backend.hcl.example backend.hcl                           # fill in
cp terraform.tfvars.example terraform.tfvars                 # fill in
tofu init -backend-config=backend.hcl
tofu plan -out tfplan
```
