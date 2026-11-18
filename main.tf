data "azapi_client_config" "current" {
  count = length(local.confidential_virtual_machines) == 0 ? 0 : 1
}

module "virtual_machine" {
  source   = "Azure/avm-res-compute-virtualmachine/azurerm"
  version  = "0.22.0"
  for_each = local.confidential_virtual_machines

  location            = each.value.location
  name                = each.value.name
  resource_group_name = each.value.resource_group_name
  zone                = each.value.zone
  account_credentials = {
    admin_credentials = {
      username                           = each.value.admin_username
      password                           = each.value.admin_password
      ssh_keys                           = lower(each.value.os_type) == "linux" && each.value.admin_password == null && each.value.admin_ssh_public_key != null ? [each.value.admin_ssh_public_key] : []
      generate_admin_password_or_ssh_key = false
    }
    password_authentication_disabled = lower(each.value.os_type) == "windows" || each.value.admin_password == null
  }
  # AVM 0.22.0's account_credentials rejects SSH keys alongside password authentication.
  # Its legacy SSH input still provisions the supplied key when Linux password auth is enabled.
  admin_ssh_keys = lower(each.value.os_type) == "linux" && each.value.admin_password != null && each.value.admin_ssh_public_key != null ? [{
    username   = each.value.admin_username
    public_key = each.value.admin_ssh_public_key
  }] : []
  computer_name = each.value.computer_name
  data_disk_existing_disks = {
    for disk_key, disk in each.value.data_disks : disk_key => {
      caching                   = disk.caching
      lun                       = disk.lun
      managed_disk_resource_id  = azapi_resource.data_disk["${each.key}:${disk_key}"].id
      write_accelerator_enabled = disk.write_accelerator_enabled
    }
  }
  enable_telemetry = var.enable_telemetry
  # Override AVM's default: encryption at host is incompatible with DiskWithVMGuestState.
  encryption_at_host_enabled = false
  ignore_body_changes        = var.ignore_body_changes.compute_virtual_machines
  managed_identities = {
    system_assigned            = contains(local.identity_types[each.key], "SystemAssigned")
    user_assigned_resource_ids = contains(local.identity_types[each.key], "UserAssigned") ? each.value.user_assigned_identity_resource_ids : []
  }
  network_interfaces = {
    primary = {
      name                           = coalesce(each.value.network_interface_name, "${each.value.name}-nic")
      accelerated_networking_enabled = each.value.accelerated_networking_enabled
      is_primary                     = true
      ip_configurations = {
        primary = {
          name                          = "ipconfig1"
          private_ip_address            = each.value.private_ip_address
          private_ip_address_allocation = each.value.private_ip_address != null ? "Static" : each.value.private_ip_address_allocation
          private_ip_subnet_resource_id = each.value.subnet_resource_id
        }
      }
    }
  }
  os_disk                = each.value.os_disk
  os_type                = each.value.os_type
  parent_id              = local.vm_resource_group_ids[each.key]
  resource_types         = var.resource_types.compute_virtual_machines
  retry                  = var.retry
  secure_boot_enabled    = each.value.secure_boot_enabled
  sku_size               = each.value.size
  source_image_reference = each.value.source_image_reference
  tags                   = each.value.tags
  timeouts               = var.timeouts
  vtpm_enabled           = each.value.vtpm_enabled
}

# Keep disks outside the AVM VM module so their zones do not inherit the VM's zone.
resource "azapi_resource" "data_disk" {
  for_each = local.data_disks

  location  = each.value.location
  name      = each.value.name
  parent_id = local.vm_resource_group_ids[each.value.vm_key]
  type      = var.resource_types.compute_disks
  body = {
    zones = each.value.zone == null ? null : [each.value.zone]
    sku = {
      name = each.value.storage_account_type
    }
    properties = {
      creationData = {
        createOption = "Empty"
      }
      diskSizeGB = each.value.disk_size_gb
      encryption = each.value.disk_encryption_set_id == null ? null : {
        diskEncryptionSetId = each.value.disk_encryption_set_id
        type                = "EncryptionAtRestWithCustomerKey"
      }
    }
  }
  ignore_body_changes    = length(var.ignore_body_changes.compute_disks) > 0 ? var.ignore_body_changes.compute_disks : null
  replace_triggers_refs  = ["zones"]
  response_export_values = []
  retry                  = var.retry
  tags                   = each.value.tags

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]
    content {
      create = timeouts.value.create
      read   = timeouts.value.read
      update = timeouts.value.update
      delete = timeouts.value.delete
    }
  }
}

module "backup" {
  source   = "Azure/avm-res-compute-virtualmachine/azurerm//modules/backup"
  version  = "0.22.0"
  for_each = local.backup_configurations

  recovery_vault_resource_id = provider::azapi::parse_resource_id("Microsoft.RecoveryServices/vaults/backupPolicies", each.value.backup_policy_resource_id).parent_id
  resource_group_name        = local.confidential_virtual_machines[each.key].resource_group_name
  virtual_machine_name       = local.confidential_virtual_machines[each.key].name
  virtualmachine_resource_id = module.virtual_machine[each.key].resource_id
  backup_policy_resource_id  = each.value.backup_policy_resource_id
  enable_telemetry           = var.enable_telemetry
  exclude_disk_luns          = each.value.exclude_disk_luns
  ignore_body_changes        = var.ignore_body_changes.recoveryservices_vaults_backupfabrics_protectioncontainers_protecteditems
  include_disk_luns          = each.value.include_disk_luns
  location                   = local.confidential_virtual_machines[each.key].location
  resource_types             = var.resource_types.recoveryservices_vaults_backupfabrics_protectioncontainers_protecteditems
  retry                      = var.retry
  timeouts                   = var.timeouts
}
