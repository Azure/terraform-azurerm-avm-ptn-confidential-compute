output "backup_protected_vm_ids" {
  description = "Resource IDs of Azure Backup protected-item associations for confidential virtual machines."
  value       = module.confidential_virtual_machine.backup_protected_vm_ids
}

output "confidential_virtual_machine_private_ip_addresses" {
  description = "Primary private IP addresses for confidential virtual machines."
  value       = module.confidential_virtual_machine.virtual_machine_private_ip_addresses
}

output "confidential_virtual_machine_resource_ids" {
  description = "Resource IDs of confidential virtual machines."
  value       = module.confidential_virtual_machine.resource_ids
}

output "confidential_virtual_machine_resource_names" {
  description = "Resource names of confidential virtual machines."
  value       = module.confidential_virtual_machine.resource_names
}

output "data_disk_attachment_resource_ids" {
  description = "Resource IDs of data disk attachments for confidential virtual machines, grouped by VM key and data-disk key."
  value       = module.confidential_virtual_machine.data_disk_attachment_resource_ids
}

output "data_disk_resource_ids" {
  description = "Resource IDs of managed data disks for confidential virtual machines, grouped by VM key and data-disk key."
  value       = module.confidential_virtual_machine.data_disk_resource_ids
}

output "network_interface_resource_ids" {
  description = "Resource IDs of network interfaces created for confidential virtual machines."
  value       = module.confidential_virtual_machine.network_interface_resource_ids
}

output "system_assigned_identity_principal_ids" {
  description = "System-assigned managed identity principal IDs keyed by VM key. Only meaningful for VMs with a system-assigned identity."
  value       = module.confidential_virtual_machine.system_assigned_identity_principal_ids
}
