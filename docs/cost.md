# Cost

Rough monthly figures for UK South at list price. Prices change, so check the Azure pricing calculator before you deploy.

| Component | Default | Approximate cost |
|---|---|---|
| VNets, peering, NSGs, route tables | on | VNets and NSGs are free; peering is charged per GB, which is pennies at idle |
| Azure Policy | on | free |
| Log Analytics | on, 1 GB/day cap | pay-per-GB ingestion; a few pounds at most at idle, capped by design |
| VNet flow logs and traffic analytics | on | per GB processed; pennies at idle |
| Key Vault (standard) | on | per 10k operations; pennies |
| Flow-log and state storage | on | pennies |
| **Azure Firewall Basic** | **off** | the largest item: hundreds of pounds a month if left running |
| **Bastion (Basic)** | **off** | around a hundred pounds a month if left running |

## Guardrails

- A £20 monthly budget alerts at 80% actual and 100% forecast.
- The Log Analytics daily cap bounds the main variable cost.
- Firewall and Bastion are flags: turn them on for a demo, then run **Destroy** or set them back to `false`.
- A free account's credit covers a full demo with the firewall on for a few hours.
