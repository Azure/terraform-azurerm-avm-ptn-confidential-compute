mock_provider "azapi" {
  mock_data "azapi_client_config" {
    defaults = {
      subscription_id          = "00000000-0000-0000-0000-000000000000"
      subscription_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
    }
  }

  mock_data "azapi_resource" {
    defaults = {
      exists = false
    }
  }
}

mock_provider "random" {
  mock_resource "random_string" {
    defaults = {
      result = "abc123"
    }
  }
}

mock_provider "time" {}
mock_provider "tls" {}

run "uses_east_us_for_backup_example" {
  command = apply

  module {
    source = "./examples/backup-enabled"
  }

  variables {
    enable_telemetry = false
    admin_password   = "UnitTest-Password123!"
  }

  override_module {
    target = module.naming
    outputs = {
      names = {
        resource_group = { name_unique = "rg-abc123" }
      }
    }
  }

  # The example appends "-01" to the naming module output.
  override_resource {
    target = azapi_resource.resource_group
    values = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-abc123-01"
    }
  }

  override_resource {
    target = azapi_resource.virtual_network
    values = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-abc123-01/providers/Microsoft.Network/virtualNetworks/vnet-cvm-backup-abc123"
    }
  }

  override_resource {
    target = azapi_resource.recovery_vault
    values = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-abc123-01/providers/Microsoft.RecoveryServices/vaults/rsv-cvm-abc123"
    }
  }

  override_resource {
    target = azapi_resource.subnet
    values = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-abc123-01/providers/Microsoft.Network/virtualNetworks/vnet-cvm-backup-abc123/subnets/snet-workload"
    }
  }

  override_resource {
    target = azapi_resource.backup_policy
    values = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-abc123-01/providers/Microsoft.RecoveryServices/vaults/rsv-cvm-abc123/backupPolicies/daily-backup"
    }
  }

  assert {
    condition = alltrue([
      azapi_resource.resource_group.location == "eastus",
      azapi_resource.virtual_network.location == "eastus",
      azapi_resource.recovery_vault.location == "eastus",
    ])
    error_message = "The backup example must deploy its resource group, network, and vault in East US."
  }

  assert {
    condition     = try(azapi_resource.recovery_vault.body.properties.publicNetworkAccess, null) == "Enabled"
    error_message = "The vault create request must explicitly enable public network access because the backup example does not provision a private endpoint."
  }

  assert {
    condition = (
      azapi_resource.backup_policy.body.properties.policyType == "V2" &&
      azapi_resource.backup_policy.body.properties.instantRpRetentionRangeInDays < azapi_resource.backup_policy.body.properties.retentionPolicy.dailySchedule.retentionDuration.count
    )
    error_message = "The backup example must use an Enhanced policy with shorter instant-restore than vaulted daily retention."
  }

  assert {
    condition = (
      module.test.backup_protected_vm_ids["cvm1"] ==
      "${trimsuffix(azapi_resource.backup_policy.id, "/backupPolicies/daily-backup")}/backupFabrics/Azure/protectionContainers/iaasvmcontainer;iaasvmcontainerv2;${azapi_resource.resource_group.name};cvm-backup-abc123/protectedItems/VM;iaasvmcontainerv2;${azapi_resource.resource_group.name};cvm-backup-abc123"
    )
    error_message = "The pattern must expose the AVM backup child protected-item ID in the selected policy vault."
  }
}
