# ADR-0001: Hub-and-spoke VNets instead of Virtual WAN

**Status:** Accepted

## Context
The landing zone needs central egress control, shared services and isolated workload networks. Azure offers customer-managed hub-and-spoke or Azure Virtual WAN.

## Decision
Use a customer-managed hub VNet with peered spoke VNets.

## Consequences
- Every component is visible in Terraform and can be inspected and costed. There is no hourly Virtual WAN hub charge.
- Routing is our responsibility (route tables per spoke subnet).
- Transitive spoke-to-spoke traffic needs the firewall. Without it, spokes cannot reach each other, which is the safe default.
- Virtual WAN would be reconsidered for many regions or many branch connections.
