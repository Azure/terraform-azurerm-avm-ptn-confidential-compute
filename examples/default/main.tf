provider "azapi" {}

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

resource "azapi_resource" "virtual_network" {
  location  = module.resource_group.location
  name      = "vnet-cvm-01"
  parent_id = module.resource_group.resource_id
  type      = "Microsoft.Network/virtualNetworks@2024-05-01"
  body = {
    properties = {
      addressSpace = { addressPrefixes = ["10.40.0.0/16"] }
    }
  }
  response_export_values = []
}

resource "azapi_resource" "subnet" {
  name      = "snet-workload"
  parent_id = azapi_resource.virtual_network.id
  type      = "Microsoft.Network/virtualNetworks/subnets@2024-05-01"
  body = {
    properties = { addressPrefix = "10.40.1.0/24" }
  }
  response_export_values = []
}

module "test" {
  source = "../../"

  location = module.resource_group.location
  confidential_virtual_machines = {
    cvm1 = {
      name                = "test"
      resource_group_name = module.resource_group.name
      subnet_resource_id  = azapi_resource.subnet.id
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

  depends_on = [module.resource_group]
}
