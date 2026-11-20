mock_provider "azapi" {
  mock_data "azapi_client_config" {
    defaults = {
      subscription_id          = "00000000-0000-0000-0000-000000000000"
      subscription_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
      tenant_id                = "00000000-0000-0000-0000-000000000000"
    }
  }
}

mock_provider "random" {}

mock_provider "time" {}

mock_provider "tls" {}

variables {
  enable_telemetry = true
  location         = "eastus"
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

run "uses_module_location_for_vm_and_telemetry" {
  command = plan

  assert {
    condition     = local.confidential_virtual_machines["vm1"].location == "eastus" && one(azapi_resource.telemetry).location == "eastus"
    error_message = "VMs without an override and telemetry must use the required module region."
  }
  providers = {
    azapi  = azapi
    random = random
    time   = time
    tls    = tls
  }
}

run "accepts_vm_level_location_override" {
  command = plan

  variables {
    confidential_virtual_machines = {
      for key, vm in var.confidential_virtual_machines : key => merge(vm, { location = "eastus2" })
    }
  }

  assert {
    condition     = local.confidential_virtual_machines["vm1"].location == "eastus2" && one(azapi_resource.telemetry).location == "eastus"
    error_message = "A VM's region override must not change the module telemetry region."
  }
  providers = {
    azapi  = azapi
    random = random
    time   = time
    tls    = tls
  }
}
