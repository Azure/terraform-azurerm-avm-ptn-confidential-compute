locals {
  confidential_virtual_machine_resource_ids = merge(
    { for key, vm in azurerm_linux_virtual_machine.this : key => vm.id },
    { for key, vm in azurerm_windows_virtual_machine.this : key => vm.id }
  )

  confidential_virtual_machine_names = merge(
    { for key, vm in azurerm_linux_virtual_machine.this : key => vm.name },
    { for key, vm in azurerm_windows_virtual_machine.this : key => vm.name }
  )

  confidential_virtual_machine_private_ips = merge(
    { for key, vm in azurerm_linux_virtual_machine.this : key => vm.private_ip_address },
    { for key, vm in azurerm_windows_virtual_machine.this : key => vm.private_ip_address }
  )

  confidential_virtual_machine_principal_ids = merge(
    { for key, vm in azurerm_linux_virtual_machine.this : key => try(vm.identity[0].principal_id, null) },
    { for key, vm in azurerm_windows_virtual_machine.this : key => try(vm.identity[0].principal_id, null) }
  )

  confidential_virtual_machine_data_disk_resource_ids_by_vm = {
    for vm_key, vm in local.confidential_virtual_machines : vm_key => {
      for disk_key, disk in vm.data_disks : disk_key => azurerm_managed_disk.data["${vm_key}:${disk_key}"].id
    }
  }

  confidential_virtual_machine_data_disk_attachment_resource_ids_by_vm = {
    for vm_key, vm in local.confidential_virtual_machines : vm_key => {
      for disk_key, disk in vm.data_disks : disk_key => azurerm_virtual_machine_data_disk_attachment.this["${vm_key}:${disk_key}"].id
    }
  }
}

output "network_interface_resource_ids" {
  description = "Resource IDs of network interfaces created for confidential virtual machines."
  value       = { for key, nic in azurerm_network_interface.this : key => nic.id }
}

output "backup_protected_vm_ids" {
  description = "Resource IDs of Azure Backup protected-item associations for confidential virtual machines."
  value       = { for key, backup in azurerm_backup_protected_vm.this : key => backup.id }
}

output "data_disk_attachment_resource_ids" {
  description = "Resource IDs of data disk attachments for confidential virtual machines, grouped by VM key and data-disk key."
  value       = local.confidential_virtual_machine_data_disk_attachment_resource_ids_by_vm
}

output "data_disk_resource_ids" {
  description = "Resource IDs of managed data disks for confidential virtual machines, grouped by VM key and data-disk key."
  value       = local.confidential_virtual_machine_data_disk_resource_ids_by_vm
}

output "resource_ids" {
  description = "Resource IDs of confidential virtual machines."
  value       = local.confidential_virtual_machine_resource_ids
}

output "resource_names" {
  description = "Resource names of confidential virtual machines."
  value       = local.confidential_virtual_machine_names
}

output "system_assigned_identity_principal_ids" {
  description = "System-assigned managed identity principal IDs keyed by VM key. Only meaningful for VMs with a system-assigned identity."
  value       = local.confidential_virtual_machine_principal_ids
}

output "virtual_machine_private_ip_addresses" {
  description = "Primary private IP addresses for confidential virtual machines."
  value       = local.confidential_virtual_machine_private_ips
}
