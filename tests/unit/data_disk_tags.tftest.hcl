mock_provider "azapi" {
  mock_data "azapi_client_config" {
    defaults = {
      subscription_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
    }
  }
}

mock_provider "azurerm" {}


run "resolves_optional_data_disk_tags" {
  command = plan

  module {
    source = "./modules/confidential-virtual-machine"
  }

  variables {
    enable_telemetry = false
    confidential_virtual_machines = {
      for key, tags in {
        untagged = null
        tagged   = { environment = "unit" }
        } : key => {
        name                = "vm-${key}"
        location            = "eastus"
        resource_group_name = "rg-test"
        subnet_resource_id  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/default"
        admin_password      = "UnitTest-Password123!"
        tags                = tags
        source_image_reference = {
          publisher = "Canonical"
          offer     = "0001-com-ubuntu-confidential-vm-jammy"
          sku       = "22_04-lts-cvm"
          version   = "latest"
        }
        data_disks = {
          inherited = {
            lun          = 0
            disk_size_gb = 128
          }
          overridden = {
            lun          = 1
            disk_size_gb = 128
            tags         = { disk = "override" }
          }
          empty = {
            lun          = 2
            disk_size_gb = 128
            tags         = {}
          }
        }
      }
    }
  }

  assert {
    condition     = azurerm_managed_disk.data["untagged:inherited"].tags == null
    error_message = "Data disks must allow both disk and VM tags to be omitted."
  }

  assert {
    condition     = azurerm_managed_disk.data["tagged:inherited"].tags == tomap({ environment = "unit" })
    error_message = "Data disks without tags must inherit VM tags."
  }

  assert {
    condition     = alltrue([for key in ["tagged", "untagged"] : azurerm_managed_disk.data["${key}:overridden"].tags == tomap({ disk = "override" })])
    error_message = "Explicit disk tags must replace VM tags."
  }

  assert {
    condition     = alltrue([for key in ["tagged", "untagged"] : length(azurerm_managed_disk.data["${key}:empty"].tags) == 0])
    error_message = "An explicit empty disk tags map must disable inheritance."
  }
}
