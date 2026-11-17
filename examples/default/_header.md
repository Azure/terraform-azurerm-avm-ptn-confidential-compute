# Default example

This standalone Terraform root deploys:

- A resource group named `rg-ckhy` by default, using the AzAPI-based AVM resource-group module.
- A virtual network and subnet in the newly created resource group.
- One Windows Server 2025 Datacenter Gen2 confidential VM named `test` (`Standard_DC2ads_v5`) and network interface through the root pattern module.
- One 128-GB Premium LRS managed data disk attached at LUN 0.

No public IP address, network security group, or backup protection is created.
The existing network and VM implementation uses AzureRM; resource-group creation and telemetry use AzAPI.

## Before deploying

Use an authenticated Azure identity and ensure the subscription has quota and confidential VM image/size availability
in the selected region. `location` defaults to `eastus` for the resource group, network, VM, disks, and telemetry.
The resource group is created by the example; it does not need to exist beforehand.
The network and VM depend on the resource-group module so creation happens in the required order.

Supply `admin_password` securely when prompted or through your secret-management workflow.
Managed GitHub Actions checks generate a temporary password input when none is supplied; see the [CI password behavior](../README.md#ci-password-behavior).
The password must contain 12-123 characters and at least three of lowercase letters, uppercase letters, digits, and special characters.
After changing this configuration, regenerate any saved Terraform plan before applying it.
Review the plan for replacements if switching from an earlier Linux deployment or a different region.

Tags are optional. Data disks inherit VM tags unless disk-level tags are supplied.

Protect local state and saved plans: they contain the administrator password. Use private-network connectivity to reach the VM.
For managed deployment and cleanup commands, see the [examples guide](../README.md).
