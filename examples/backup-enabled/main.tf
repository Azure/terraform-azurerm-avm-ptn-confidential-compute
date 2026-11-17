terraform {
  required_version = ">= 1.9, < 2.0"

  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.12"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
  }
}

provider "azapi" {}

provider "azurerm" {
  features {}
}

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

resource "azurerm_resource_group" "this" {
  location = var.location
  name     = module.naming.names.resource_group.name_unique
}

resource "azurerm_virtual_network" "this" {
  location            = azurerm_resource_group.this.location
  name                = "vnet-cvm-backup-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.this.name
  address_space       = ["10.50.0.0/16"]

  depends_on = [azurerm_resource_group.this]
}

resource "azurerm_subnet" "this" {
  name                 = "snet-workload"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = ["10.50.1.0/24"]

  depends_on = [azurerm_virtual_network.this]
}

resource "azurerm_recovery_services_vault" "this" {
  location            = azurerm_resource_group.this.location
  name                = "rsv-cvm-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "Standard"

  depends_on = [azurerm_resource_group.this]
}

resource "azurerm_backup_policy_vm" "this" {
  name                           = "daily-backup"
  recovery_vault_name            = azurerm_recovery_services_vault.this.name
  resource_group_name            = azurerm_resource_group.this.name
  instant_restore_retention_days = 2
  policy_type                    = "V2"
  timezone                       = "UTC"

  backup {
    frequency = "Daily"
    time      = "23:00"
  }

  retention_daily {
    count = 7
  }

  depends_on = [azurerm_recovery_services_vault.this]
}

module "test" {
  source = "../../"

  location = azurerm_resource_group.this.location
  confidential_virtual_machines = {
    cvm1 = {
      name                = "cvm-backup-${random_string.suffix.result}"
      resource_group_name = azurerm_resource_group.this.name
      subnet_resource_id  = azurerm_subnet.this.id
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
        recovery_vault_resource_group_name = azurerm_resource_group.this.name
        recovery_vault_name                = azurerm_recovery_services_vault.this.name
        backup_policy_resource_id          = azurerm_backup_policy_vm.this.id
      }
    }
  }
  enable_telemetry = var.enable_telemetry

  depends_on = [azurerm_recovery_services_vault.this, azurerm_backup_policy_vm.this]
}
