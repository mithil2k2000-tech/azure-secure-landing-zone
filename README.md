# Azure Secure Landing Zone

A small, production-style Azure landing zone built with Terraform (OpenTofu-compatible). It has a hub-and-spoke network, policy as code and a CI/CD pipeline with security gates. Designed to run at near-zero cost by default.

![CI](../../actions/workflows/ci.yml/badge.svg)

## What it builds

| Layer | Resources |
|---|---|
| Hub | VNet (10.0.0.0/22), Log Analytics (1 GB/day cap), Key Vault (RBAC, purge protection, network deny), VNet flow logs with traffic analytics. Optional: Azure Firewall Basic, Bastion. |
| Spokes | `app` (10.1.0.0/22) and `data` (10.2.0.0/22). Each has NSGs that allow only declared ports from private ranges and deny other inbound traffic. Default outbound access is off, and it can route through the firewall. |
| Governance | 6 custom Azure Policy definitions in an initiative assigned to the subscription. Microsoft cloud security benchmark runs audit-only. Activity log goes to Log Analytics, with a £20 monthly budget alert. |
| Pipeline | Gitleaks, fmt/validate/tflint, a policy JSON linter, Checkov and Trivy (SARIF results go to GitHub code scanning), then a plan. Apply is manual, runs from `main` only, and needs reviewer approval. |
| Identity | GitHub OIDC with no stored secrets. A read-only **plan** identity is kept separate from the **apply** identity. Apply can only grant one role (Key Vault Administrator), enforced by an ABAC condition. |

```mermaid
flowchart LR
  subgraph Hub["Hub VNet 10.0.0.0/22"]
    FW[Azure Firewall Basic<br/>optional]
    BAS[Bastion<br/>optional]
    KV[Key Vault]
    LAW[Log Analytics]
  end
  subgraph App["Spoke: app 10.1.0.0/22"]
    WEB[snet-web :443]
    API[snet-api :8443]
  end
  subgraph Data["Spoke: data 10.2.0.0/22"]
    DB[snet-db :5432]
    PE[snet-private-endpoints]
  end
  App <-- peering --> Hub
  Data <-- peering --> Hub
  App -. 0.0.0.0/0 via firewall .-> FW
  Data -. 0.0.0.0/0 via firewall .-> FW
  POL[Azure Policy initiative] --- Hub & App & Data
```

## Repository layout

```
modules/hub      hub network, logging, Key Vault, optional firewall and Bastion
modules/spoke    reusable spoke: subnets, NSGs, routes, peering, flow log
modules/policy   loads policies/definitions/*.json, builds and assigns the initiative
policies/        policy definitions as JSON (the source of truth)
environments/dev root module wiring it together
bootstrap/       one-time script: state storage and the two OIDC identities
.github/         CI (security gates and plan), deploy and destroy workflows
docs/            architecture, ADRs, controls mapping, cost, deployment guide
```

## Security gates

Every pull request runs these checks:

1. **Gitleaks** scans the full history for secrets.
2. **tofu fmt / validate** and **tflint** (azurerm ruleset) check formatting, validity and lint rules.
3. **scripts/check_policies.py** checks that each policy definition has the required fields, a parameterised effect that allows `Disabled`, and valid modes.
4. **Checkov** runs Terraform misconfiguration checks. Every skip is justified inline.
5. **Trivy** runs a config scan and fails on HIGH or CRITICAL findings.
6. **Plan** runs with a read-only identity and posts the plan summary to the run.

Current local results: Checkov 56 passed, 0 failed (9 justified skips); tflint clean; policy lint 6 definitions, 0 errors.

## Docs

- [Architecture](docs/architecture.md)
- [Architecture decision records](docs/adr/)
- [CIS / NIST 800-53 / MCSB controls mapping](docs/controls-mapping.md)
- [Cost](docs/cost.md)
- [Deploying](docs/deploy.md)

## Quick start

See [docs/deploy.md](docs/deploy.md). In short:

1. Run `bootstrap/bootstrap.sh <owner/repo>`.
2. Add the variables it prints to GitHub.
3. Create the `dev-plan` and `dev` environments.
4. Open a PR to see the plan, then run **Deploy** with `confirm=apply`.

Tear down with the **Destroy** workflow when you're not using it.
