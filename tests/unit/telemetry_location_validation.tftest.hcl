mock_provider "azapi" {
  mock_data "azapi_client_config" {
    defaults = {
      subscription_id          = "00000000-0000-0000-0000-000000000000"
      subscription_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
      tenant_id                = "00000000-0000-0000-0000-000000000000"
    }
  }
}

mock_provider "azurerm" {}

mock_provider "modtm" {}

override_module {
  target = module.confidential_virtual_machine
}

variables {
  enable_telemetry = false
  confidential_virtual_machines = {
    vm1 = {
      name                = "vm-test"
      resource_group_name = "rg-test"
      subnet_resource_id  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/default"
      source_image_reference = {
        publisher = "Canonical"
        offer     = "0001-com-ubuntu-confidential-vm-jammy"
        sku       = "22_04-lts-cvm"
        version   = "latest"
      }
      admin_username       = "azureuser"
      admin_ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCtest"
    }
  }
}

run "rejects_missing_telemetry_location" {
  command = plan

  variables {
    enable_telemetry = true
    location         = null
    confidential_virtual_machines = {
      vm1 = {
        name                = "vm-test"
        location            = null
        resource_group_name = "rg-test"
        subnet_resource_id  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/default"
        source_image_reference = {
          publisher = "Canonical"
          offer     = "0001-com-ubuntu-confidential-vm-jammy"
          sku       = "22_04-lts-cvm"
          version   = "latest"
        }
        admin_username       = "azureuser"
        admin_ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCtest"
      }
    }
  }

  expect_failures = [
    var.confidential_virtual_machines,
  ]
  providers = {
    azapi   = azapi
    azurerm = azurerm
    modtm   = modtm
  }
}

run "accepts_vm_level_location_for_telemetry" {
  command = plan

  variables {
    enable_telemetry = true
    location         = null
    confidential_virtual_machines = {
      vm1 = {
        name                = "vm-test"
        location            = "eastus2"
        resource_group_name = "rg-test"
        subnet_resource_id  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/default"
        source_image_reference = {
          publisher = "Canonical"
          offer     = "0001-com-ubuntu-confidential-vm-jammy"
          sku       = "22_04-lts-cvm"
          version   = "latest"
        }
        admin_username       = "azureuser"
        admin_ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCtest"
      }
    }
  }

  assert {
    condition     = local.telemetry_location == "eastus2"
    error_message = "telemetry_location should resolve from the first VM location when module-level location is null."
  }
  providers = {
    azapi   = azapi
    azurerm = azurerm
    modtm   = modtm
  }
}
