mock_provider "azapi" {
  mock_data "azapi_client_config" {
    defaults = {
      subscription_id          = "00000000-0000-0000-0000-000000000000"
      subscription_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
    }
  }
}

mock_provider "azurerm" {
  mock_resource "azurerm_network_interface" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ckhy/providers/Microsoft.Network/networkInterfaces/test-nic"
    }
  }

  mock_resource "azurerm_managed_disk" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ckhy/providers/Microsoft.Compute/disks/test-data01"
    }
  }

  mock_resource "azurerm_subnet" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ckhy/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/snet-workload"
    }
  }

  mock_resource "azurerm_windows_virtual_machine" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ckhy/providers/Microsoft.Compute/virtualMachines/test"
    }
  }
}

mock_provider "random" {}

run "windows_example" {
  command = apply

  module {
    source = "./examples/default"
  }

  variables {
    enable_telemetry = false
    admin_password   = "UnitTest-Password123!"
  }

  assert {
    condition     = module.resource_group.name == "rg-ckhy" && module.resource_group.location == "eastus"
    error_message = "The default example must create its resource group in East US."
  }

  assert {
    condition     = module.test.confidential_virtual_machine_resource_ids["cvm1"] == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ckhy/providers/Microsoft.Compute/virtualMachines/test"
    error_message = "The default example must create a Windows VM through the pattern module."
  }

  assert {
    condition     = azurerm_virtual_network.this.location == "eastus" && azurerm_virtual_network.this.resource_group_name == "rg-ckhy"
    error_message = "The default example must use East US and the newly created resource group without random region selection."
  }
}
