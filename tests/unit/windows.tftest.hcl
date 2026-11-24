mock_provider "azapi" {
  mock_data "azapi_client_config" {
    defaults = {
      subscription_id          = "00000000-0000-0000-0000-000000000000"
      subscription_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
    }
  }
}

mock_provider "random" {}

mock_provider "time" {}

mock_provider "tls" {}

run "windows_confidential_security_profile" {
  command = plan

  variables {
    enable_telemetry = false
    location         = "eastus"
    confidential_virtual_machines = {
      cvm1 = {
        name                = "cvm-windows"
        resource_group_name = "rg-test"
        subnet_resource_id  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/default"
        admin_password      = "UnitTest-Password123!"
        os_type             = "Windows"
        source_image_reference = {
          publisher = "MicrosoftWindowsServer"
          offer     = "WindowsServer"
          sku       = "2025-datacenter-g2"
          version   = "latest"
        }
      }
    }
  }

  override_resource {
    target          = module.virtual_machine["cvm1"].azapi_resource.virtualmachine_network_interfaces["primary"]
    override_during = plan
    values = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/networkInterfaces/cvm-windows-nic"
    }
  }

  assert {
    condition     = !can(module.virtual_machine["cvm1"].resource.body.properties.securityProfile.encryptionAtHost)
    error_message = "The Windows VM request must omit encryption at host; sending the property requires subscription feature registration."
  }

  assert {
    condition = nonsensitive(
      module.virtual_machine["cvm1"].resource.body.properties.securityProfile.securityType == "ConfidentialVM" &&
      module.virtual_machine["cvm1"].resource.body.properties.securityProfile.uefiSettings.secureBootEnabled &&
      module.virtual_machine["cvm1"].resource.body.properties.securityProfile.uefiSettings.vTpmEnabled &&
      module.virtual_machine["cvm1"].resource.body.properties.storageProfile.osDisk.managedDisk.securityProfile.securityEncryptionType == "DiskWithVMGuestState"
    )
    error_message = "Omitting encryption at host must preserve the Windows VM's confidential OS disk and UEFI security settings."
  }
  providers = {
    azapi  = azapi
    random = random
    time   = time
    tls    = tls
  }
}

run "windows_example" {
  command = apply

  module {
    source = "./examples/default"
  }

  variables {
    enable_telemetry = false
    admin_password   = "UnitTest-Password123!"
  }

  override_resource {
    target = module.resource_group.azapi_resource.this[0]
    values = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ckhy"
    }
  }

  override_resource {
    target = azapi_resource.virtual_network
    values = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ckhy/providers/Microsoft.Network/virtualNetworks/vnet-cvm-01"
    }
  }

  override_resource {
    target = azapi_resource.subnet
    values = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ckhy/providers/Microsoft.Network/virtualNetworks/vnet-cvm-01/subnets/snet-workload"
    }
  }

  override_resource {
    target = module.test.module.virtual_machine["cvm1"].azapi_resource.virtualmachine_network_interfaces["primary"]
    values = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ckhy/providers/Microsoft.Network/networkInterfaces/test-nic"
      output = {
        properties = {
          ipConfigurations = [{ properties = { primary = true, privateIPAddress = "10.40.1.4" } }]
        }
      }
    }
  }

  override_resource {
    target = module.test.azapi_resource.data_disk["cvm1:data01"]
    values = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ckhy/providers/Microsoft.Compute/disks/test-data01"
    }
  }

  override_resource {
    target = module.test.module.virtual_machine["cvm1"].azapi_resource.this_windows_virtual_machine[0]
    values = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ckhy/providers/Microsoft.Compute/virtualMachines/test"
    }
  }

  assert {
    condition     = module.resource_group.name == "rg-ckhy" && azapi_resource.virtual_network.location == "eastus"
    error_message = "The default example must create its resource group and network in East US."
  }

  assert {
    condition = (
      module.test.confidential_virtual_machine_resource_ids["cvm1"] == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ckhy/providers/Microsoft.Compute/virtualMachines/test" &&
      module.test.confidential_virtual_machine_private_ip_addresses["cvm1"] == "10.40.1.4"
    )
    error_message = "The pattern must expose the AVM Windows VM ID and the NIC's primary private IP."
  }

  assert {
    condition     = module.test.data_disk_attachment_resource_ids["cvm1"]["data01"] == "${module.test.confidential_virtual_machine_resource_ids["cvm1"]}/dataDisks/test-data01"
    error_message = "The data disk attachment output must retain the legacy ID based on the managed disk name."
  }
}
