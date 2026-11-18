mock_provider "azapi" {
  mock_data "azapi_client_config" {
    defaults = {
      subscription_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
    }
  }
}

mock_provider "random" {}

mock_provider "time" {}

mock_provider "tls" {}

override_resource {
  target = module.virtual_machine["vm1"].azapi_resource.virtualmachine_network_interfaces["primary"]
  values = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/networkInterfaces/vm-test-nic"
  }
}

override_resource {
  target = module.virtual_machine["vm1"].azapi_resource.this_linux_virtual_machine[0]
  values = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/virtualMachines/vm-test"
  }
}

override_resource {
  target = azapi_resource.data_disk["vm1:data01"]
  values = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/disks/vm-test-data01"
  }
}

variables {
  enable_telemetry = false
  location         = "eastus"
  tags = {
    environment = "unit"
  }
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
      data_disks = {
        data01 = {
          lun          = 0
          disk_size_gb = 128
        }
      }
    }
  }
}

run "normalizes_defaults_and_forwards_outputs" {
  command = apply

  assert {
    condition     = local.confidential_virtual_machines.vm1.location == "eastus"
    error_message = "The root module should default VM location from module-level location."
  }

  assert {
    condition     = azapi_resource.data_disk["vm1:data01"].tags == tomap({ environment = "unit" })
    error_message = "A data disk must inherit module-level tags when neither the VM nor the disk overrides them."
  }

  assert {
    condition     = output.confidential_virtual_machine_resource_ids.vm1 == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/virtualMachines/vm-test"
    error_message = "The root output must expose the AVM-managed VM ID."
  }

  assert {
    condition     = output.data_disk_resource_ids.vm1.data01 == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/disks/vm-test-data01"
    error_message = "The root output must expose managed disk IDs keyed by VM and disk."
  }

  providers = {
    azapi  = azapi
    random = random
    time   = time
    tls    = tls
  }
}
