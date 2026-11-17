# Backup-enabled example

This standalone Terraform root deploys:

- A resource group, virtual network, and subnet.
- One Windows Server 2025 Datacenter Gen2 confidential VM (`Standard_DC2as_v5`) and network interface through the root pattern module.
- A Windows computer name using the `cvm-bk-` prefix and six-character suffix to stay within the 15-character limit.
- A Standard Recovery Services vault and a VM backup policy scheduled daily at 23:00 UTC with seven daily recovery points retained.
- An Azure Backup protection association between the VM and that policy.

The VM has no additional data disks. No public IP address or network security group is created.
The example uses AzureRM for infrastructure; the pattern module uses AzAPI for telemetry.

## Before deploying

Use an authenticated Azure identity with VM, networking, and backup permissions, and verify confidential VM quota,
image/size availability, and Azure Backup support in the selected region.
`location` defaults to `eastus` and directly sets the resource group's location, which is shared by the network, VM,
backup vault, and telemetry. The example does not select a random region.

Supply `admin_password` securely when prompted or through your secret-management workflow.
The password must contain 12-123 characters and at least three of lowercase letters, uppercase letters, digits, and special characters.
Regenerate saved plans after configuration changes. Switching an existing Linux VM to Windows requires recreation;
review the VM and backup-protection changes before applying.

Protect local state and saved plans: they contain the administrator password. Use private-network connectivity to reach the VM.
Enabling protection does not verify a completed backup or restore. Recovery points and vault soft-delete settings
can require additional cleanup before Azure permits vault deletion.
For managed deployment and cleanup commands, see the [examples guide](../README.md).
