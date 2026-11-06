# ADR-0005: VNet flow logs instead of NSG flow logs

**Status:** Accepted

## Context
Microsoft is retiring NSG flow logs and no longer allows new NSG flow logs to be created. VNet flow logs replace them, covering all traffic in a VNet regardless of NSG placement.

## Decision
- Enable VNet flow logs on the hub and each spoke, with traffic analytics sent to the central workspace.
- Reuse Azure's automatically created `NetworkWatcher_<region>` in `NetworkWatcherRG`. A second watcher is not allowed per region per subscription; `create_network_watcher` exists for subscriptions where it was never created.

## Consequences
- Needs azurerm 4.x (`target_resource_id` on `azurerm_network_watcher_flow_log`).
- Flow-log storage and traffic analytics are billed by volume. The 1 GB/day workspace cap bounds the analytics side.
