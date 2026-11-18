output "backup_protected_vm_ids" {
  depends_on  = [module.backup]
  description = "Resource IDs of Azure Backup protected-item associations for confidential virtual machines."
  value       = { for key, backup in module.backup : key => backup.resource_id }
}

output "confidential_virtual_machine_private_ip_addresses" {
  description = "Primary private IP addresses for confidential virtual machines."
  value       = { for key, vm in module.virtual_machine : key => vm.network_interfaces.primary.private_ip_address }
}

output "confidential_virtual_machine_resource_ids" {
  description = "Resource IDs of confidential virtual machines."
  value       = { for key, vm in module.virtual_machine : key => vm.resource_id }
}

output "confidential_virtual_machine_resource_names" {
  description = "Resource names of confidential virtual machines."
  value       = { for key, vm in module.virtual_machine : key => vm.name }
}

output "data_disk_attachment_resource_ids" {
  description = "Legacy synthetic attachment IDs, in the form <vm-id>/dataDisks/<managed-disk-name>, grouped by VM and disk key. These are not independently addressable ARM resources."
  value = {
    for vm_key, vm in local.confidential_virtual_machines : vm_key => {
      for disk_key in keys(vm.data_disks) : disk_key => "${module.virtual_machine[vm_key].resource_id}/dataDisks/${azapi_resource.data_disk["${vm_key}:${disk_key}"].name}"
    }
  }
}

output "data_disk_resource_ids" {
  description = "Resource IDs of managed data disks for confidential virtual machines, grouped by VM key and data-disk key."
  value = {
    for vm_key, vm in local.confidential_virtual_machines : vm_key => {
      for disk_key in keys(vm.data_disks) : disk_key => azapi_resource.data_disk["${vm_key}:${disk_key}"].id
    }
  }
}

output "network_interface_resource_ids" {
  description = "Resource IDs of network interfaces created for confidential virtual machines."
  value       = { for key, vm in module.virtual_machine : key => vm.network_interfaces.primary.id }
}

output "system_assigned_identity_principal_ids" {
  description = "System-assigned managed identity principal IDs keyed by VM key; null for VMs without a system-assigned identity."
  value       = { for key, vm in module.virtual_machine : key => contains(local.identity_types[key], "SystemAssigned") ? vm.system_assigned_mi_principal_id : null }
}
