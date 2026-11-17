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

removed {
  from = azurerm_resource_group.this

  lifecycle {
    destroy = false
  }
}

module "resource_group" {
  source  = "Azure/avm-res-resources-resourcegroup/azurerm"
  version = "0.5.0"

  location         = var.location
  name             = var.resource_group_name
  enable_telemetry = var.enable_telemetry
}

resource "azurerm_virtual_network" "this" {
  location            = module.resource_group.location
  name                = "vnet-cvm-01"
  resource_group_name = module.resource_group.name
  address_space       = ["10.40.0.0/16"]

  depends_on = [module.resource_group]
}

resource "azurerm_subnet" "this" {
  name                 = "snet-workload"
  resource_group_name  = module.resource_group.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = ["10.40.1.0/24"]

  depends_on = [azurerm_virtual_network.this]
}

module "test" {
  source = "../../"

  location = module.resource_group.location
  confidential_virtual_machines = {
    cvm1 = {
      name                = "test"
      resource_group_name = module.resource_group.name
      subnet_resource_id  = azurerm_subnet.this.id
      source_image_reference = {
        publisher = "MicrosoftWindowsServer"
        offer     = "WindowsServer"
        sku       = "2025-datacenter-g2"
        version   = "latest"
      }
      admin_username = "azureuser"
      admin_password = var.admin_password
      computer_name  = "test"
      os_type        = "Windows"
      size           = "Standard_DC2ads_v5"
      data_disks = {
        data01 = {
          lun                  = 0
          disk_size_gb         = 128
          storage_account_type = "Premium_LRS"
          caching              = "ReadWrite"
        }
      }
    }
  }
  enable_telemetry = var.enable_telemetry

  depends_on = [azurerm_subnet.this, module.resource_group]
}
