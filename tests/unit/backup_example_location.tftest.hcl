mock_provider "azapi" {}

mock_provider "azurerm" {
  mock_resource "azurerm_network_interface" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-backup/providers/Microsoft.Network/networkInterfaces/backup-nic"
    }
  }

  mock_resource "azurerm_subnet" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-backup/providers/Microsoft.Network/virtualNetworks/vnet-backup/subnets/snet-workload"
    }
  }

  mock_resource "azurerm_windows_virtual_machine" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-backup/providers/Microsoft.Compute/virtualMachines/backup"
    }
  }

  mock_resource "azurerm_backup_policy_vm" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-backup/providers/Microsoft.RecoveryServices/vaults/rsv-backup/backupPolicies/daily-backup"
    }
  }
}

mock_provider "modtm" {}

mock_provider "random" {}

run "uses_east_us_for_backup_example" {
  command = apply

  module {
    source = "./examples/backup-enabled"
  }

  variables {
    enable_telemetry = false
    admin_password   = "UnitTest-Password123!"
  }

  assert {
    condition = alltrue([
      azurerm_resource_group.this.location == "eastus",
      azurerm_virtual_network.this.location == "eastus",
      azurerm_recovery_services_vault.this.location == "eastus",
    ])
    error_message = "The backup example must deploy its resource group, network, and vault in East US without random region selection."
  }

  assert {
    condition     = module.test.confidential_virtual_machine_resource_ids["cvm1"] == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-backup/providers/Microsoft.Compute/virtualMachines/backup"
    error_message = "The backup example must create a Windows VM through the pattern module."
  }

  assert {
    condition     = contains(keys(module.test.backup_protected_vm_ids), "cvm1")
    error_message = "The backup example must retain protection for the Windows VM."
  }
}
