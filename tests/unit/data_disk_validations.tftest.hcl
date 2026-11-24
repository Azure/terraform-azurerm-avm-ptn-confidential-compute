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

variables {
  enable_telemetry = false
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
      data_disks = {
        data01 = {
          lun          = 0
          disk_size_gb = 128
        }
      }
    }
  }
}

run "rejects_empty_virtual_machine_map" {
  command = plan

  variables {
    confidential_virtual_machines = {}
  }

  expect_failures = [var.confidential_virtual_machines]
  providers = {
    azapi  = azapi
    random = random
    time   = time
    tls    = tls
  }
}

run "rejects_invalid_identity_type" {
  command = plan

  variables {
    confidential_virtual_machines = merge(var.confidential_virtual_machines, {
      invalid = merge(var.confidential_virtual_machines.vm1, {
        name          = "vm-invalid"
        identity_type = "systemassigned"
        data_disks    = {}
      })
    })
  }

  expect_failures = [var.confidential_virtual_machines]
  providers = {
    azapi  = azapi
    random = random
    time   = time
    tls    = tls
  }
}

run "rejects_empty_identity_type" {
  command = plan

  variables {
    confidential_virtual_machines = {
      for key, vm in var.confidential_virtual_machines : key => merge(vm, {
        identity_type = ""
      })
    }
  }

  expect_failures = [var.confidential_virtual_machines]
  providers = {
    azapi  = azapi
    random = random
    time   = time
    tls    = tls
  }
}

run "supports_identity_modes" {
  command = plan

  variables {
    confidential_virtual_machines = {
      for key, identity_type in {
        default  = null
        none     = "None"
        system   = "SystemAssigned"
        user     = "UserAssigned"
        both     = "SystemAssigned, UserAssigned"
        compact  = "SystemAssigned,UserAssigned"
        reversed = "UserAssigned, SystemAssigned"
        } : key => merge(var.confidential_virtual_machines.vm1, {
          name                                = "vm-${key}"
          user_assigned_identity_resource_ids = ["/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.ManagedIdentity/userAssignedIdentities/identity-test"]
          data_disks                          = {}
      }, identity_type == null ? {} : { identity_type = identity_type })
    }
  }

  assert {
    condition = nonsensitive(alltrue([
      for key in ["default", "none"] :
      !contains(keys(module.virtual_machine[key].resource.body), "identity") &&
      output.system_assigned_identity_principal_ids[key] == null
    ]))
    error_message = "Omitting identity_type or setting None must omit VM identity configuration even when user-assigned IDs are supplied."
  }

  assert {
    condition = nonsensitive(
      module.virtual_machine["system"].resource.body.identity.type == "SystemAssigned" &&
      !contains(keys(module.virtual_machine["system"].resource.body.identity), "userAssignedIdentities")
    )
    error_message = "SystemAssigned must enable only a system-assigned identity."
  }

  assert {
    condition     = nonsensitive(module.virtual_machine["user"].resource.body.identity.type == "UserAssigned")
    error_message = "UserAssigned must not enable a system-assigned identity."
  }

  assert {
    condition = nonsensitive(alltrue([
      for key in ["both", "compact", "reversed"] :
      module.virtual_machine[key].resource.body.identity.type == "SystemAssigned, UserAssigned"
    ]))
    error_message = "Combined identity modes must preserve both identities regardless of comma spacing or ordering."
  }

  assert {
    condition = nonsensitive(alltrue([
      for key in ["user", "both", "compact", "reversed"] :
      toset(keys(module.virtual_machine[key].resource.body.identity.userAssignedIdentities)) == toset(var.confidential_virtual_machines[key].user_assigned_identity_resource_ids)
    ]))
    error_message = "Modes including UserAssigned must forward the supplied identity IDs to the VM."
  }

  providers = {
    azapi  = azapi
    random = random
    time   = time
    tls    = tls
  }
}

run "configures_data_disk_encryption" {
  command = plan

  variables {
    confidential_virtual_machines = {
      for key, vm in var.confidential_virtual_machines : key => merge(vm, {
        data_disks = merge(vm.data_disks, {
          data02 = {
            lun                    = 1
            disk_size_gb           = 128
            disk_encryption_set_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/diskEncryptionSets/des-test"
          }
        })
      })
    }
  }

  assert {
    condition = try(azapi_resource.data_disk["vm1:data01"].body.properties.encryption == {
      diskEncryptionSetId = tostring(null)
      type                = "EncryptionAtRestWithPlatformKey"
    }, false)
    error_message = "A data disk without an encryption set must explicitly match Azure's platform-managed encryption."
  }

  assert {
    condition = (
      azapi_resource.data_disk["vm1:data02"].body.properties.encryption.type == "EncryptionAtRestWithCustomerKey" &&
      azapi_resource.data_disk["vm1:data02"].body.properties.encryption.diskEncryptionSetId == var.confidential_virtual_machines["vm1"].data_disks["data02"].disk_encryption_set_id
    )
    error_message = "A data disk with an encryption set must use the supplied customer-managed key."
  }
  providers = {
    azapi  = azapi
    random = random
    time   = time
    tls    = tls
  }
}

run "rejects_backup_policy_in_a_different_vault" {
  command = plan

  variables {
    confidential_virtual_machines = {
      for key, vm in var.confidential_virtual_machines : key => merge(vm, {
        backup_configuration = {
          recovery_vault_resource_group_name = "rg-backup"
          recovery_vault_name                = "rsv-test"
          backup_policy_resource_id          = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-backup/providers/Microsoft.RecoveryServices/vaults/rsv-other/backupPolicies/daily"
        }
      })
    }
  }

  expect_failures = [var.confidential_virtual_machines]
  providers = {
    azapi  = azapi
    random = random
    time   = time
    tls    = tls
  }
}

run "rejects_duplicate_data_disk_luns" {
  command = plan

  variables {
    confidential_virtual_machines = {
      vm1 = {
        name                = "vm-test"
        location            = "eastus"
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
          data02 = {
            lun          = 0
            disk_size_gb = 256
          }
        }
      }
    }
  }

  expect_failures = [
    var.confidential_virtual_machines,
  ]
  providers = {
    azapi  = azapi
    random = random
    time   = time
    tls    = tls
  }
}

run "rejects_backup_include_lun_not_in_data_disks" {
  command = plan

  variables {
    confidential_virtual_machines = {
      vm1 = {
        name                = "vm-test"
        location            = "eastus"
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
        backup_configuration = {
          recovery_vault_resource_group_name = "rg-backup"
          recovery_vault_name                = "rsv-test"
          backup_policy_resource_id          = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-backup/providers/Microsoft.RecoveryServices/vaults/rsv-test/backupPolicies/daily"
          include_disk_luns                  = [5]
        }
      }
    }
  }

  expect_failures = [
    var.confidential_virtual_machines,
  ]
  providers = {
    azapi  = azapi
    random = random
    time   = time
    tls    = tls
  }
}

run "rejects_invalid_data_disk_caching" {
  command = plan

  variables {
    confidential_virtual_machines = {
      vm1 = {
        name                = "vm-test"
        location            = "eastus"
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
            caching      = "Invalid"
          }
        }
      }
    }
  }

  expect_failures = [
    var.confidential_virtual_machines,
  ]
  providers = {
    azapi  = azapi
    random = random
    time   = time
    tls    = tls
  }
}
