# ADR-0006: GitHub OIDC with separate plan and apply identities

**Status:** Accepted

## Context
Long-lived client secrets in CI are a common source of leaks. A single all-powerful pipeline identity also lets any pull request workflow change production.

## Decision
- Use GitHub OIDC federated credentials, with no secrets stored anywhere.
- Create two identities:
  - **plan**: Reader on the subscription plus state access. Federated only to the `dev-plan` environment.
  - **apply**: deploy rights. Federated only to the `dev` environment, which has required reviewers and runs only from `main`.
- Limit the apply identity's role-assignment rights with an ABAC condition, so it can grant only Key Vault Administrator.

## Consequences
- A malicious pull request can at most read the subscription. It cannot change it.
- The apply identity cannot escalate itself to Owner or User Access Administrator.
- Contributor is still broad. A production setup would use custom roles per resource type.
