# ADR-0003: Azure Firewall Basic, off by default

**Status:** Accepted

## Context
Central egress filtering is a core landing-zone control. Azure Firewall Standard and Premium cost several hundred pounds a month. This is a portfolio environment that runs only when needed.

## Decision
- Implement Azure Firewall with the **Basic** SKU and a firewall policy.
- Put it behind `enable_firewall`, which defaults to `false`. Bastion likewise sits behind `enable_bastion`.

## Consequences
- The default deployment costs pennies. Turning on the firewall shows the full design for a demo, then it can be torn down.
- Basic has no IDPS, TLS inspection or threat-intelligence deny mode. A production landing zone would use Premium.
- Basic needs a management subnet and public IP, which is why Checkov skip CKV2_AZURE_31 exists on that subnet.
