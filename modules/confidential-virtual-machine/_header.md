# Confidential virtual machine

This submodule deploys Azure Confidential Virtual Machines and their network interfaces.

It supports Linux and Windows, optional managed data disks and attachments, managed identities,
and optional Azure Backup protection through an existing Recovery Services vault policy.
It uses AzureRM for these resources and AzAPI for its telemetry deployment.

Prefer the [root pattern module](../../README.md) when you need shared location and tag defaults.
When calling this submodule directly:

- Set `location` inside every VM definition. The separate module-level `location` is used only for telemetry and does not default VM locations.
- Supply existing resource groups and subnets, plus a compatible confidential VM image, size, region, and quota.
- Provide either a password or SSH public key for Linux and a password for Windows. Protect state containing passwords.
- Data disks inherit VM tags unless disk tags are supplied; tags may be omitted at both levels.
  Disk tags replace VM tags, including an explicit empty map. Disk zones must be set independently of VM zones.
- Supply an existing vault and VM backup policy to enable backup. Include/exclude LUN sets are mutually exclusive
  and must reference data disks declared on the same VM.
- Configure providers in the calling Terraform root. No public IP address, network security group,
  resource group, virtual network, subnet, vault, or policy is created by this submodule.

Outputs use the VM keys from `confidential_virtual_machines`; disk outputs additionally use each VM's data-disk keys.
Backup outputs contain only protected VMs. Principal IDs are meaningful only for system-assigned identities.

Telemetry defaults to enabled and requires module-level `location` and subscription-scoped deployment permissions.
Set `enable_telemetry = false` to disable the empty telemetry deployment; this does not remove per-VM location requirements.
