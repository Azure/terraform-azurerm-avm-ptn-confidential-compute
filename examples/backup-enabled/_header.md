# Backup-enabled example

This standalone Terraform root deploys:

- A resource group, virtual network, and subnet.
- One Windows Server 2025 Datacenter Gen2 confidential VM (`Standard_DC2as_v5`) and network interface through the root pattern module.
- A Windows computer name using the `cvm-bk-` prefix and six-character suffix to stay within the 15-character limit.
- A Standard Recovery Services vault and an Enhanced (`V2`) VM backup policy scheduled daily at 23:00 UTC, with two days of instant-restore snapshots and seven days of vaulted daily recovery points.
- An Azure Backup protection association between the VM and that policy.

The VM has no additional data disks. No public IP address or network security group is created.
The Recovery Services vault has public network access enabled; this example does not provision a vault private endpoint.
The example uses AzAPI for supporting infrastructure and calls the root pattern directly. The pattern uses the
published AVM VM and backup modules for the confidential VM and its protection.

## Before deploying

Use an authenticated Azure identity with VM, networking, and backup permissions, and verify confidential VM quota,
image/size availability, and Azure Backup support in the selected region.
`location` defaults to `eastus` and directly sets the resource group's location, which is shared by the network, VM,
backup vault, and telemetry. The example does not select a random region.

The demonstrated VM requires an Enhanced backup policy. The vault's `Standard` SKU is independent of the backup
policy type and remains unchanged. The pattern module associates the supplied policy; it does not create or convert policies.
Instant-restore retention is explicitly set to two days, strictly below the seven-day vaulted daily retention.
Do not omit this setting: Enhanced policies default to seven days of instant-restore retention, which conflicts
with this example's seven-day vaulted retention. For daily and weekly schedules, vaulted retention must exceed
instant-restore retention.
Changing an existing policy from `V1` to `V2` forces policy replacement in Terraform. Review the plan before applying.
If the old policy already protects other VMs, preserve their protection and follow the supported
[Enhanced-policy migration guidance](https://learn.microsoft.com/azure/backup/backup-azure-vms-enhanced-policy)
rather than deleting protected items or recovery points.

Supply `admin_password` securely when prompted or through your secret-management workflow.
Managed GitHub Actions checks generate a temporary password input when none is supplied; see the [CI password behavior](../README.md#ci-password-behavior).
The password must contain 12-123 characters and at least three of lowercase letters, uppercase letters, digits, and special characters.
Regenerate saved plans after configuration changes. Switching an existing Linux VM to Windows requires recreation;
review the VM and backup-protection changes before applying.
If upgrading from the former wrapper layout, follow the [state migration guide](../../README.md#upgrading-an-existing-deployment)
with `module.test` as the pattern's address.

Protect local state and saved plans: they contain the administrator password. Use private-network connectivity to reach the VM.
Enabling protection does not verify a completed backup or restore.

## Cleanup and data loss

This example creates disposable test infrastructure and explicitly sets `retain_backup_data_on_destroy = false`.
Destroy therefore requests deletion of backup data rather than stopping protection and retaining recovery points.
The reusable pattern module defaults this setting to `true`.

Soft delete remains enabled. After vault creation, the example reads the
[Azure Backup configuration](https://learn.microsoft.com/rest/api/backup/backup-resource-vault-configs/get?view=rest-backup-2024-04-01)
and requires `Enabled` or `AlwaysON` before configuring protection. It does not change soft-delete settings or bypass
their retention period. If an earlier deployment disabled soft delete, re-enable it through your approved
vault-management workflow before applying.
A delete request can leave soft-deleted backup items, preventing immediate vault deletion and causing managed
E2E cleanup to fail.

**Destroying this example requests backup data deletion. Do not use these cleanup settings for production backups.**
For production, retain recovery points in an independently managed vault with soft delete enabled.
Azure cannot delete a vault while it contains retained or soft-deleted backup items; follow the
[vault deletion requirements](https://learn.microsoft.com/azure/backup/backup-azure-delete-vault).
Inspect any remaining backup items, vault, and resource group after cleanup failures; remaining resources can incur charges.

For an existing deployment, apply any change to `retain_backup_data_on_destroy` while backup protection is still
in Terraform state, before removing its configuration or destroying it. Changing configuration cannot retroactively
change an already executed destroy request.
For managed deployment and cleanup commands, see the [examples guide](../README.md).
