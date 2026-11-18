# Azure Confidential Compute

Terraform pattern module for Azure Confidential Virtual Machines.

The root module accepts a map of Linux or Windows VM definitions, applies default locations and tags, and creates:

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
- An SSH public key or password for Linux; a password is required for Windows. Protect Terraform state and any backups of state from earlier versions.
- For backup, an existing compatible Recovery Services vault and VM backup policy, and permissions to configure VM protection.
  Use an Enhanced (`V2`) policy for the VM configuration in the backup-enabled example. The module associates the
  supplied policy ID; it does not create policies or upgrade Standard (`V1`) policies to Enhanced.
  For daily/weekly Enhanced policies, explicitly configure instant-restore retention shorter than vaulted retention.

The pattern uses the [AVM Virtual Machine module v0.22.0](https://registry.terraform.io/modules/Azure/avm-res-compute-virtualmachine/azurerm/0.22.0)
for VMs and networking and its backup submodule for protection. AzAPI creates the managed data disks separately so their
zones and tags remain independent of the VM's. The pattern does not require the AzureRM provider; `/azurerm` is a
legacy Registry suffix. Configure AzAPI in your calling Terraform root.

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

- The root `location` is required and must not be null. It supplies the region for VMs without their own `location`;
  per-VM overrides remain supported. Both examples supply `eastus` by default.
- VM-level `tags` replace, rather than merge with, root `tags`. Data-disk tags similarly replace VM tags.
  Tags may be omitted at all levels. An explicit empty disk tags map disables inheritance.
- A supplied `private_ip_address` forces static allocation. Otherwise allocation defaults to `Dynamic`.
  No public IP address, network security group, or remote-access service is created.
- The pattern does not request [encryption at host](https://learn.microsoft.com/azure/virtual-machines/disk-encryption#encryption-at-host---end-to-end-encryption-for-your-vm-data)
  or require its subscription feature registration. Confidential OS disk encryption (`DiskWithVMGuestState` by default),
  Secure Boot, and vTPM are configured separately.
- Data-disk keys must be stable at plan time. LUNs must be unique within each VM and between 0 and 63.
  Set a data disk's zone explicitly when required; it does not inherit the VM's zone.
- Backup include/exclude LUN sets are mutually exclusive and can reference only LUNs declared in that VM's `data_disks`.
  The vault name and resource group must match the backup policy ID. Creating a protection association is not evidence
  that a backup or restore has completed.
- VM outputs are maps keyed by the VM input keys. Disk outputs are nested maps keyed by VM and disk keys.
  Backup outputs contain only VMs with backup configured; disk maps are empty for VMs without additional disks.
  Disk attachment IDs retain the legacy `<vm-id>/dataDisks/<managed-disk-name>` format; they are not ARM resource IDs.

## Upgrading an existing deployment

The former `//modules/confidential-virtual-machine` source is no longer available. Use the root module and provide its
required `location`. If you used the earlier nested AzAPI overrides, move fields from
`resource_types.confidential_virtual_machine` and `ignore_body_changes.confidential_virtual_machine` into the respective
top-level objects.

Terraform does not migrate state automatically. Pause concurrent applies, securely back up the state, and test the
upgrade outside production. Use `terraform state list` and `terraform state show` to confirm addresses and resource IDs.
Do not apply a plan that destroys or replaces existing VMs, disks, NICs, or backup protection.

### If your deployment already uses AzAPI and the AVM VM

Run `terraform state mv` for the entries that exist in your state. The addresses below are relative to the pattern module.
For example, prefix both sides with `module.confidential_compute.` if that is the module call in your Terraform root.
Use your actual VM keys. Moving each keyed VM or backup module moves the resources it contains.

| Old address | New address |
|---|---|
| `module.confidential_virtual_machine.module.virtual_machine["vm-key"]` | `module.virtual_machine["vm-key"]` |
| `module.confidential_virtual_machine.module.backup["vm-key"]` | `module.backup["vm-key"]` |
| `module.confidential_virtual_machine.azapi_resource.data_disk` | `azapi_resource.data_disk` |

If present, forget the wrapper's `module.confidential_virtual_machine.azapi_resource.telemetry[0]` and
`module.confidential_virtual_machine.terraform_data.telemetry[0]` with `terraform state rm` rather than deleting the
Azure telemetry deployment. Do not remove root or AVM module telemetry bindings. Review the resulting plan before applying.

### If your deployment still uses AzureRM

The old AzureRM VM, NIC, disk, and attachment bindings cannot be moved using the table above. Keep your deployment on
its previous revision until you have tested adoption. In an isolated test deployment, evaluate forgetting the old
bindings without destroying the resources and importing the existing resources at these addresses. The table assumes
your module call is named `confidential_compute`; substitute your actual module label, VM key, and disk key.

| Existing object | Target address |
|---|---|
| Linux VM | `module.confidential_compute.module.virtual_machine["vm-key"].azapi_resource.this_linux_virtual_machine[0]` |
| Windows VM | `module.confidential_compute.module.virtual_machine["vm-key"].azapi_resource.this_windows_virtual_machine[0]` |
| NIC | `module.confidential_compute.module.virtual_machine["vm-key"].azapi_resource.virtualmachine_network_interfaces["primary"]` |
| Data disk | `module.confidential_compute.azapi_resource.data_disk["vm-key:disk-key"]` |

Attachments are part of the AVM-managed VM body, so there is no separate attachment to import. The AVM backup child
looks up the existing protected item; do not delete the old protection to migrate it. Verify the plan and check for
unintended workload changes after test adoption. The AzureRM adoption path has not been verified against live state.

## Telemetry

Telemetry is enabled by default. Set `enable_telemetry = false` to disable it in the entire pattern, including the AVM VM and backup modules.
The required root `location` supplies telemetry's region even when individual VMs override their deployment region.
Disabling telemetry does not make the root `location` optional.

The pattern and its instrumented modules create empty Azure deployments at subscription scope for telemetry.
The deployment identity needs `Microsoft.Resources/deployments/read`, `write`, and `delete` permissions at that scope.
Telemetry deployment failures fail the apply. These deployments intentionally update on normal applies,
even when the VM configuration is unchanged. See [AVM telemetry guidance](https://aka.ms/avm/telemetryinfo).

## Development

See the [tests guide](tests/README.md) for validation commands and coverage, and the [contribution guide](CONTRIBUTING.md)
for contribution policies. Use PowerShell 7.4 or later with [Avm.Authoring](https://github.com/Azure/azure-verified-modules-tools#install).
Edit `_header.md`, `_footer.md`, and variable/output descriptions, then run `avm docs` to regenerate the module and example README files.
The directory indexes in `examples/README.md`, `modules/README.md`, and `tests/README.md` are authored guides.
Run `avm pre-commit`, review its changes, and run `avm pr-check` only after committing your intended changes and obtaining a clean worktree.
