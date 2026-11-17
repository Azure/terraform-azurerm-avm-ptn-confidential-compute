locals {
  confidential_virtual_machines         = var.confidential_virtual_machines
  linux_confidential_virtual_machines   = { for key, value in local.confidential_virtual_machines : key => value if lower(value.os_type) == "linux" }
  windows_confidential_virtual_machines = { for key, value in local.confidential_virtual_machines : key => value if lower(value.os_type) == "windows" }
  confidential_virtual_machine_backup_configurations = {
    for key, value in local.confidential_virtual_machines : key => value.backup_configuration
    if value.backup_configuration != null
  }
  confidential_virtual_machine_data_disks = length(local.confidential_virtual_machines) == 0 ? {} : merge([
    for vm_key, vm in local.confidential_virtual_machines : {
      for disk_key, disk in vm.data_disks : "${vm_key}:${disk_key}" => merge(disk, {
        vm_key              = vm_key
        vm_name             = vm.name
        location            = vm.location
        resource_group_name = vm.resource_group_name
        tags                = disk.tags != null ? disk.tags : vm.tags
        disk_key            = disk_key
      })
    }
  ]...)
}

resource "azurerm_network_interface" "this" {
  for_each = local.confidential_virtual_machines

  location            = each.value.location
  name                = coalesce(each.value.network_interface_name, "${each.value.name}-nic")
  resource_group_name = each.value.resource_group_name
  tags                = each.value.tags

  accelerated_networking_enabled = each.value.accelerated_networking_enabled

  ip_configuration {
    name                          = "ipconfig1"
    private_ip_address            = each.value.private_ip_address
    private_ip_address_allocation = each.value.private_ip_address != null ? "Static" : each.value.private_ip_address_allocation
    subnet_id                     = each.value.subnet_resource_id
  }
}

resource "azurerm_managed_disk" "data" {
  for_each = local.confidential_virtual_machine_data_disks

  create_option          = "Empty"
  disk_size_gb           = each.value.disk_size_gb
  disk_encryption_set_id = each.value.disk_encryption_set_id
  location               = each.value.location
  name                   = coalesce(each.value.name, "${each.value.vm_name}-${each.value.disk_key}")
  resource_group_name    = each.value.resource_group_name
  storage_account_type   = each.value.storage_account_type
  tags                   = each.value.tags
  zone                   = each.value.zone
}

resource "azurerm_linux_virtual_machine" "this" {
  for_each = local.linux_confidential_virtual_machines

  admin_password                  = each.value.admin_password
  admin_username                  = each.value.admin_username
  computer_name                   = each.value.computer_name
  disable_password_authentication = each.value.admin_password == null
  location                        = each.value.location
  name                            = each.value.name
  network_interface_ids           = [azurerm_network_interface.this[each.key].id]
  resource_group_name             = each.value.resource_group_name
  secure_boot_enabled             = each.value.secure_boot_enabled
  size                            = each.value.size
  tags                            = each.value.tags
  vtpm_enabled                    = each.value.vtpm_enabled
  zone                            = each.value.zone

  source_image_reference {
    offer     = each.value.source_image_reference.offer
    publisher = each.value.source_image_reference.publisher
    sku       = each.value.source_image_reference.sku
    version   = each.value.source_image_reference.version
  }

  os_disk {
    caching                          = each.value.os_disk.caching
    disk_size_gb                     = each.value.os_disk.disk_size_gb
    secure_vm_disk_encryption_set_id = each.value.os_disk.secure_vm_disk_encryption_set_id
    security_encryption_type         = each.value.os_disk.security_encryption_type
    storage_account_type             = each.value.os_disk.storage_account_type
  }

  dynamic "admin_ssh_key" {
    for_each = each.value.admin_ssh_public_key == null ? [] : [each.value.admin_ssh_public_key]
    content {
      public_key = admin_ssh_key.value
      username   = each.value.admin_username
    }
  }

  dynamic "identity" {
    for_each = each.value.identity_type == null ? [] : [each.value]
    content {
      type         = identity.value.identity_type
      identity_ids = contains(split(",", replace(identity.value.identity_type, " ", "")), "UserAssigned") ? tolist(identity.value.user_assigned_identity_resource_ids) : null
    }
  }
}

resource "azurerm_windows_virtual_machine" "this" {
  for_each = local.windows_confidential_virtual_machines

  admin_password        = each.value.admin_password
  admin_username        = each.value.admin_username
  computer_name         = each.value.computer_name
  location              = each.value.location
  name                  = each.value.name
  network_interface_ids = [azurerm_network_interface.this[each.key].id]
  resource_group_name   = each.value.resource_group_name
  secure_boot_enabled   = each.value.secure_boot_enabled
  size                  = each.value.size
  tags                  = each.value.tags
  vtpm_enabled          = each.value.vtpm_enabled
  zone                  = each.value.zone

  source_image_reference {
    offer     = each.value.source_image_reference.offer
    publisher = each.value.source_image_reference.publisher
    sku       = each.value.source_image_reference.sku
    version   = each.value.source_image_reference.version
  }

  os_disk {
    caching                          = each.value.os_disk.caching
    disk_size_gb                     = each.value.os_disk.disk_size_gb
    secure_vm_disk_encryption_set_id = each.value.os_disk.secure_vm_disk_encryption_set_id
    security_encryption_type         = each.value.os_disk.security_encryption_type
    storage_account_type             = each.value.os_disk.storage_account_type
  }

  dynamic "identity" {
    for_each = each.value.identity_type == null ? [] : [each.value]
    content {
      type         = identity.value.identity_type
      identity_ids = contains(split(",", replace(identity.value.identity_type, " ", "")), "UserAssigned") ? tolist(identity.value.user_assigned_identity_resource_ids) : null
    }
  }
}

resource "azurerm_virtual_machine_data_disk_attachment" "this" {
  for_each = local.confidential_virtual_machine_data_disks

  caching                   = each.value.caching
  lun                       = each.value.lun
  managed_disk_id           = azurerm_managed_disk.data[each.key].id
  virtual_machine_id        = local.confidential_virtual_machine_resource_ids[each.value.vm_key]
  write_accelerator_enabled = each.value.write_accelerator_enabled
}

resource "azurerm_backup_protected_vm" "this" {
  for_each = local.confidential_virtual_machine_backup_configurations

  backup_policy_id    = each.value.backup_policy_resource_id
  recovery_vault_name = each.value.recovery_vault_name
  resource_group_name = each.value.recovery_vault_resource_group_name
  source_vm_id        = local.confidential_virtual_machine_resource_ids[each.key]
  exclude_disk_luns   = each.value.exclude_disk_luns
  include_disk_luns   = each.value.include_disk_luns
}
