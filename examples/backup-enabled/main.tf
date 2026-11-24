provider "azapi" {}

resource "random_string" "suffix" {
  length  = 6
  lower   = true
  numeric = true
  special = false
  upper   = false
}

module "naming" {
  source  = "Azure/avm-utl-naming/azure"
  version = "0.2.0"
}

data "azapi_client_config" "current" {}

resource "azapi_resource" "resource_group" {
  location               = var.location
  name                   = "${module.naming.names.resource_group.name_unique}-01"
  parent_id              = data.azapi_client_config.current.subscription_resource_id
  type                   = "Microsoft.Resources/resourceGroups@2024-03-01"
  response_export_values = []
}

resource "azapi_resource" "virtual_network" {
  location  = azapi_resource.resource_group.location
  name      = "vnet-cvm-backup-${random_string.suffix.result}"
  parent_id = azapi_resource.resource_group.id
  type      = "Microsoft.Network/virtualNetworks@2024-05-01"
  body = {
    properties = { addressSpace = { addressPrefixes = ["10.50.0.0/16"] } }
  }
  response_export_values = []
}

resource "azapi_resource" "subnet" {
  name      = "snet-workload"
  parent_id = azapi_resource.virtual_network.id
  type      = "Microsoft.Network/virtualNetworks/subnets@2024-05-01"
  body = {
    properties = { addressPrefix = "10.50.1.0/24" }
  }
  response_export_values = []
}

resource "azapi_resource" "recovery_vault" {
  location  = azapi_resource.resource_group.location
  name      = "rsv-cvm-${random_string.suffix.result}"
  parent_id = azapi_resource.resource_group.id
  type      = "Microsoft.RecoveryServices/vaults@2024-04-01"
  body = {
    sku = { name = "Standard" }
    properties = {
      publicNetworkAccess = "Enabled"
    }
  }
  response_export_values = []
}

resource "azapi_update_resource" "backup_config" {
  name      = "vaultconfig"
  parent_id = azapi_resource.recovery_vault.id
  type      = "Microsoft.RecoveryServices/vaults/backupconfig@2024-04-01"
  body = {
    properties = {
      softDeleteFeatureState = "Disabled"
    }
  }
  response_export_values = []
}

resource "azapi_resource" "backup_policy" {
  name      = "daily-backup"
  parent_id = azapi_resource.recovery_vault.id
  type      = "Microsoft.RecoveryServices/vaults/backupPolicies@2024-10-01"
  body = {
    properties = {
      backupManagementType          = "AzureIaasVM"
      policyType                    = "V2"
      timeZone                      = "UTC"
      instantRpRetentionRangeInDays = 2
      schedulePolicy = {
        schedulePolicyType   = "SimpleSchedulePolicyV2"
        scheduleRunFrequency = "Daily"
        dailySchedule        = { scheduleRunTimes = ["2018-07-30T23:00:00Z"] }
      }
      retentionPolicy = {
        retentionPolicyType = "LongTermRetentionPolicy"
        dailySchedule = {
          retentionTimes    = ["2018-07-30T23:00:00Z"]
          retentionDuration = { count = 7, durationType = "Days" }
        }
      }
    }
  }
  response_export_values = []

  # Protection must wait for the vault's post-create soft-delete configuration.
  depends_on = [azapi_update_resource.backup_config]
}

module "test" {
  source = "../../"

  confidential_virtual_machines = {
    cvm1 = {
      name                = "cvm-backup-${random_string.suffix.result}"
      resource_group_name = azapi_resource.resource_group.name
      subnet_resource_id  = azapi_resource.subnet.id
      source_image_reference = {
        publisher = "MicrosoftWindowsServer"
        offer     = "WindowsServer"
        sku       = "2025-datacenter-g2"
        version   = "latest"
      }
      admin_username = "azureuser"
      admin_password = var.admin_password
      computer_name  = "cvm-bk-${random_string.suffix.result}"
      os_type        = "Windows"
      size           = "Standard_DC2as_v5"
      backup_configuration = {
        recovery_vault_resource_group_name = azapi_resource.resource_group.name
        recovery_vault_name                = azapi_resource.recovery_vault.name
        backup_policy_resource_id          = azapi_resource.backup_policy.id
        retain_backup_data_on_destroy      = false
      }
    }
  }
  location         = azapi_resource.resource_group.location
  enable_telemetry = var.enable_telemetry
}
