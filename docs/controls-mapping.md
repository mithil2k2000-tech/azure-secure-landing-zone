# Controls mapping

How each control in this repository maps to NIST SP 800-53 Rev. 5, the Microsoft cloud security benchmark (MCSB) and the CIS Microsoft Azure Foundations Benchmark (by section, since numbering changes between versions). Evidence links to the file that implements it.

| Control in this repo | Evidence | NIST 800-53 | MCSB | CIS Azure (section) |
|---|---|---|---|---|
| Hub-and-spoke segmentation, no spoke-to-spoke peering | `modules/spoke/main.tf` | SC-7 | NS-1 | Networking |
| NSGs: declared ports only, explicit deny-all inbound | `modules/spoke/main.tf` | SC-7, AC-4, CM-7 | NS-1 | Networking |
| Deny RDP/SSH from internet (policy) | `policies/definitions/deny-mgmt-ports-from-internet.json` | SC-7, AC-17 | NS-1 | Networking (RDP/SSH from internet) |
| Deny public IPs on NICs (policy) | `policies/definitions/deny-public-ip-on-nic.json` | SC-7 | NS-2 | Networking |
| No default outbound access, egress via firewall | `modules/spoke`, `modules/hub` | SC-7(5), SC-7(7) | NS-3 | Networking |
| Bastion for admin access (no public IPs on VMs) | `modules/hub/main.tf` | AC-17, AC-17(3) | PA-1, NS-1 | Networking |
| Allowed locations (policy) | `policies/definitions/allowed-locations.json` | CM-6, SA-9(5) | AM-2 | n/a |
| Mandatory ownership/cost tags (policy) | `policies/definitions/require-tags.json` | CM-8, PM-5 | AM-1 | n/a |
| Storage: HTTPS only, TLS 1.2, no public blob access, no shared keys | `modules/hub/main.tf`, `storage-secure-transfer.json` | SC-8, AC-3, IA-2 | DP-3, IM-1 | Storage Accounts |
| Key Vault: RBAC, purge protection, soft delete, network deny | `modules/hub/main.tf`, `keyvault-purge-protection.json` | SC-12, CP-9, AC-6 | DP-6, DP-8 | Key Vault |
| Activity log to Log Analytics | `environments/dev/main.tf` | AU-2, AU-6, AU-12 | LT-3, LT-5 | Logging and Monitoring |
| Key Vault and firewall diagnostics | `modules/hub/main.tf` | AU-2, AU-12 | LT-3, LT-4 | Logging and Monitoring |
| VNet flow logs with traffic analytics | `modules/hub`, `modules/spoke` | AU-12, SI-4 | LT-4 | Networking / Logging |
| Log retention setting | `var.log_retention_days` | AU-11 | LT-6 | Logging and Monitoring |
| MCSB initiative assigned (audit) | `modules/policy/main.tf` | CA-7, RA-5 | PV-1 | Microsoft Defender / Policy |
| Budget alert | `environments/dev/main.tf` | PM-3 | n/a | n/a |
| OIDC, no stored CI secrets | `.github/workflows/*`, `bootstrap/bootstrap.sh` | IA-5, IA-2 | IM-3 | Identity |
| Separate plan/apply identities, ABAC-limited role assignment | `bootstrap/bootstrap.sh` | AC-6, AC-5 | PA-7 | Identity |
| Manual, reviewed apply from `main` only | `.github/workflows/deploy.yml` | CM-3, CM-5 | DS-6 | n/a |
| Secret scanning (Gitleaks) | `.github/workflows/ci.yml` | SA-11, IA-5(7) | DS-6 | n/a |
| IaC scanning (Checkov, Trivy, tflint) and policy lint | `.github/workflows/ci.yml` | SA-11, CM-2, RA-5 | DS-6, PV-5 | n/a |
| State with Entra auth, versioning, soft delete | `bootstrap/bootstrap.sh` | AC-3, CP-9 | BR-1 | Storage Accounts |
