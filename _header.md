# Azure Confidential Compute

Terraform pattern module for Azure Confidential Virtual Machines.

The root module composes the [confidential virtual machine submodule](modules/confidential-virtual-machine/README.md).
It accepts a map of Linux or Windows VM definitions, applies default locations and tags, and creates:

- One network interface and confidential VM per definition.
- Optional managed data disks and their attachments.
- Optional Azure Backup protection using an existing Recovery Services vault and VM backup policy.

The root module does not create resource groups, virtual networks, subnets, backup vaults, or backup policies.
The [examples](examples/README.md) create their own prerequisites.

## Prerequisites

- Terraform and provider versions satisfying the generated requirements below.
- An authenticated Azure identity with permissions to manage the requested resources.
- An existing resource group and subnet for each VM. The subnet must be usable by the VM's network interface.
- A confidential-compute-compatible VM size and image available in the selected region and zone, with sufficient subscription quota.
- An SSH public key or password for Linux; a password is required for Windows. Protect Terraform state because passwords are retained in state.
- For backup, an existing compatible Recovery Services vault and VM backup policy, and permissions to configure VM protection.
  Use an Enhanced (`V2`) policy for the VM configuration in the backup-enabled example. The module associates the
  supplied policy ID; it does not create policies or upgrade Standard (`V1`) policies to Enhanced.
  For daily/weekly Enhanced policies, explicitly configure instant-restore retention shorter than vaulted retention.

The current VM, networking, data-disk, and backup implementation uses the AzureRM provider.
AzAPI is used for subscription-scoped telemetry deployments. Configure the providers in the calling Terraform root;
this reusable module does not configure them. The legacy `/azurerm` module address is distinct from these provider requirements.

## Usage

The following module call assumes this repository is checked out in a directory named
`terraform-azurerm-avm-ptn-confidential-compute` beneath the calling Terraform root.
Replace the resource names, subnet ID, and public-key path with your own values.

```hcl
module "confidential_compute" {
  source = "./terraform-azurerm-avm-ptn-confidential-compute"

  location = "eastus"
  tags = {
    environment = "development"
  }
  confidential_virtual_machines = {
    cvm1 = {
      name                = "cvm-eastus-001"
      resource_group_name = "rg-confidential-eastus-001"
      subnet_resource_id  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-confidential-eastus-001/providers/Microsoft.Network/virtualNetworks/vnet-confidential-eastus-001/subnets/workload"
      source_image_reference = {
        publisher = "Canonical"
        offer     = "0001-com-ubuntu-confidential-vm-jammy"
        sku       = "22_04-lts-cvm"
        version   = "latest"
      }
      admin_username       = "azureuser"
      admin_ssh_public_key = file("~/.ssh/id_rsa.pub")
      size                 = "Standard_DC2as_v5"
    }
  }
}
```

For runnable Terraform roots, see the [default Windows Server 2025 example](examples/default/README.md), which creates
its resource group, network, and a 128-GB data disk, and the [backup-enabled Windows Server 2025 example](examples/backup-enabled/README.md).
Both examples default to East US (`eastus`) without random region selection. Their VM sizes differ; verify quota and
image availability for the selected example. The root module itself does not impose an East US default.

## Configuration behavior

- Every VM needs either its own `location` or the root `location`.
- VM-level `tags` replace, rather than merge with, root `tags`. Data-disk tags similarly replace VM tags.
  Tags may be omitted at all levels. An explicit empty disk tags map disables inheritance.
- A supplied `private_ip_address` forces static allocation. Otherwise allocation defaults to `Dynamic`.
  No public IP address, network security group, or remote-access service is created.
- Data-disk keys must be stable at plan time. LUNs must be unique within each VM and between 0 and 63.
  Set a data disk's zone explicitly when required; it does not inherit the VM's zone.
- Backup include/exclude LUN sets are mutually exclusive and can reference only LUNs declared in that VM's `data_disks`.
  Creating a protection association is not evidence that a backup or restore has completed.
- VM outputs are maps keyed by the VM input keys. Disk outputs are nested maps keyed by VM and disk keys.
  Backup outputs contain only VMs with backup configured; disk maps are empty for VMs without additional disks.

## Telemetry

Telemetry is enabled by default. Set `enable_telemetry = false` on the module call to disable it in both the root and child module.
With telemetry enabled, `location` is used for telemetry, falling back to the first VM's resolved location when omitted.
An empty VM map therefore still requires `location` unless telemetry is disabled.

Both modules create an empty Azure deployment at the active subscription scope for telemetry.
The deployment identity needs `Microsoft.Resources/deployments/read`, `write`, and `delete` permissions at that scope.
Telemetry deployment failures fail the apply. These deployments intentionally update on normal applies,
even when the VM configuration is unchanged. See [AVM telemetry guidance](https://aka.ms/avm/telemetryinfo).

## Development

See the [tests guide](tests/README.md) for validation commands and coverage, and the [contribution guide](CONTRIBUTING.md)
for contribution policies. Use PowerShell 7.4 or later with [Avm.Authoring](https://github.com/Azure/azure-verified-modules-tools#install).
Edit `_header.md`, `_footer.md`, and variable/output descriptions, then run `avm docs` to regenerate the module and example README files.
The directory indexes in `examples/README.md`, `modules/README.md`, and `tests/README.md` are authored guides.
Run `avm pre-commit`, review its changes, and run `avm pr-check` only after committing your intended changes and obtaining a clean worktree.
