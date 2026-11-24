locals {
  confidential_virtual_machines = {
    for key, value in var.confidential_virtual_machines : key => merge(value, {
      location = coalesce(value.location, var.location)
      tags     = value.tags != null ? value.tags : var.tags
    })
  }

  vm_resource_group_ids = {
    for key, vm in local.confidential_virtual_machines : key => "${data.azapi_client_config.current.subscription_resource_id}/resourceGroups/${vm.resource_group_name}"
  }
  identity_types = {
    for key, vm in local.confidential_virtual_machines : key => split(",", replace(coalesce(vm.identity_type, "None"), " ", ""))
  }
  backup_configurations = {
    for key, vm in local.confidential_virtual_machines : key => vm.backup_configuration if vm.backup_configuration != null
  }
  data_disks = merge({}, [
    for vm_key, vm in local.confidential_virtual_machines : {
      for disk_key, disk in vm.data_disks : "${vm_key}:${disk_key}" => merge(disk, {
        vm_key   = vm_key
        name     = coalesce(disk.name, "${vm.name}-${disk_key}")
        location = vm.location
        tags     = disk.tags != null ? disk.tags : vm.tags
      })
    }
  ]...)
}
