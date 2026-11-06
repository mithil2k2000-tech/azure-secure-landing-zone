# ADR-0002: Policy definitions as JSON files, assigned as one initiative

**Status:** Accepted

## Context
Guardrails should be reviewable, testable and versioned with the infrastructure. Writing policy rules inline in HCL makes them hard to read and to reuse outside Terraform.

## Decision
- Keep each custom policy as a standalone JSON file in `policies/definitions/`. The policy module loads them with `fileset` and `jsondecode`.
- Group them in one initiative and assign it at subscription scope.
- Every definition exposes an `effect` parameter that allows `Disabled`. The assignment has an enforcement switch.
- Assign the Microsoft cloud security benchmark separately, audit-only.

## Consequences
- The files are the same format the Azure portal and CLI use, so they can be tested or deployed on their own.
- `scripts/check_policies.py` lints them in CI.
- Adding a policy means adding one file. No Terraform change is needed.
- Deny policies can break deployments. New rules should go out with `policy_enforce = false` first.
