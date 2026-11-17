mock_provider "azapi" {}

mock_provider "azurerm" {}

mock_provider "modtm" {}

override_module {
  target = module.confidential_virtual_machine
  outputs = {
    backup_protected_vm_ids = {
      vm1 = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.RecoveryServices/vaults/rsv-test/backupFabrics/Azure/protectionContainers/iaasvmcontainer;iaasvmcontainerv2;rg-test;vm-test/protectedItems/vm;iaasvmcontainerv2;rg-test;vm-test"
    }
    data_disk_attachment_resource_ids = {
      vm1 = {
        data01 = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/virtualMachines/vm-test/dataDisks/0"
      }
    }
    data_disk_resource_ids = {
      vm1 = {
        data01 = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/disks/vm-test-data01"
      }
    }
    network_interface_resource_ids = {
      vm1 = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/networkInterfaces/vm-test-nic"
    }
    resource_ids = {
      vm1 = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/virtualMachines/vm-test"
    }
    resource_names = {
      vm1 = "vm-test"
    }
    system_assigned_identity_principal_ids = {
      vm1 = "00000000-0000-0000-0000-000000000001"
    }
    virtual_machine_private_ip_addresses = {
      vm1 = "10.0.1.4"
    }
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
    condition     = local.confidential_virtual_machines.vm1.tags.environment == "unit"
    error_message = "The root module should default VM tags from module-level tags."
  }

  assert {
    condition     = local.telemetry_location == "eastus"
    error_message = "telemetry_location should resolve from the module-level location."
  }

  assert {
    condition     = output.confidential_virtual_machine_resource_ids.vm1 == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/virtualMachines/vm-test"
    error_message = "Root outputs should pass through submodule VM IDs."
  }

  assert {
    condition     = output.data_disk_resource_ids.vm1.data01 == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/disks/vm-test-data01"
    error_message = "Root outputs should pass through submodule data disk IDs."
  }

  providers = {
    azapi   = azapi
    azurerm = azurerm
    modtm   = modtm
  }
}
