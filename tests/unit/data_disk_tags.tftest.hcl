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

run "linux_dual_auth" {
  command = plan

  variables {
    enable_telemetry = false
    location         = "eastus"
    confidential_virtual_machines = {
      dual = {
        name                 = "cvm-linux"
        resource_group_name  = "rg-test"
        subnet_resource_id   = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/default"
        admin_password       = "UnitTest-Password123!"
        admin_ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCtest"
        source_image_reference = {
          publisher = "Canonical"
          offer     = "0001-com-ubuntu-confidential-vm-jammy"
          sku       = "22_04-lts-cvm"
          version   = "latest"
        }
      }
    }
  }

  override_resource {
    target          = module.virtual_machine["dual"].azapi_resource.virtualmachine_network_interfaces["primary"]
    override_during = plan
    values = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/networkInterfaces/cvm-linux-nic"
    }
  }

  assert {
    condition = nonsensitive(
      module.virtual_machine["dual"].resource.body.properties.securityProfile.securityType == "ConfidentialVM" &&
      module.virtual_machine["dual"].resource.body.properties.securityProfile.uefiSettings.secureBootEnabled &&
      module.virtual_machine["dual"].resource.body.properties.securityProfile.uefiSettings.vTpmEnabled &&
      module.virtual_machine["dual"].resource.body.properties.storageProfile.osDisk.managedDisk.securityProfile.securityEncryptionType == "DiskWithVMGuestState"
    )
    error_message = "The AVM VM must receive the default confidential OS disk and UEFI security settings."
  }

  assert {
    condition = nonsensitive(
      !module.virtual_machine["dual"].resource.body.properties.osProfile.linuxConfiguration.disablePasswordAuthentication &&
      length(module.virtual_machine["dual"].resource.body.properties.osProfile.linuxConfiguration.ssh.publicKeys) == 1
    )
    error_message = "Configuring Linux password authentication must not discard the supplied SSH key."
  }
  providers = {
    azapi  = azapi
    random = random
    time   = time
    tls    = tls
  }
}

run "resolves_optional_data_disk_tags" {
  command = plan

  variables {
    enable_telemetry = false
    location         = "eastus"
    confidential_virtual_machines = {
      for key, tags in {
        untagged = null
        tagged   = { environment = "unit" }
        } : key => {
        name                = "vm-${key}"
        zone                = "1"
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
            zone         = "1"
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
    condition     = local.data_disks["untagged:inherited"].tags == null
    error_message = "Data disks must allow both disk and VM tags to be omitted."
  }

  assert {
    condition     = azapi_resource.data_disk["tagged:inherited"].tags == tomap({ environment = "unit" })
    error_message = "Data disks without tags must inherit VM tags."
  }

  assert {
    condition     = alltrue([for key in ["tagged", "untagged"] : azapi_resource.data_disk["${key}:overridden"].tags == tomap({ disk = "override" })])
    error_message = "Explicit disk tags must replace VM tags."
  }

  assert {
    condition     = alltrue([for key in ["tagged", "untagged"] : length(azapi_resource.data_disk["${key}:empty"].tags) == 0])
    error_message = "An explicit empty disk tags map must disable inheritance."
  }

  assert {
    condition     = azapi_resource.data_disk["tagged:inherited"].body.zones == null && one(azapi_resource.data_disk["tagged:overridden"].body.zones) == "1"
    error_message = "Data disks must retain independent placement: omit zones unless the disk itself specifies one."
  }
  providers = {
    azapi  = azapi
    random = random
    time   = time
    tls    = tls
  }
}
