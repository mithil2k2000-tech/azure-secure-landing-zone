# ADR-0004: Private endpoints and Private DNS deferred

**Status:** Accepted (revisit when a workload is added)

## Context
Key Vault and storage should ideally be reachable only through private endpoints with Private DNS zones linked to the hub. That needs a resolver design and costs per endpoint per hour. There is no workload in this repository yet that would consume them.

## Decision
- Lock down PaaS with network ACLs for now: Key Vault default deny, plus storage with public access disabled and no shared keys.
- Reserve `snet-private-endpoints` in the data spoke for later.

## Consequences
- Checkov skip CKV_AZURE_189 is justified here: Key Vault public network access stays enabled but default-deny. Without that, the runner could not manage it before private endpoints exist.
- The next iteration adds private endpoints, Private DNS zones in the hub, and a policy that denies public network access.
