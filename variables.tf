variable "location" {
  type        = string
  description = "Required Azure region used for telemetry and as the default for VMs that omit their own location."
  nullable    = false
}

variable "confidential_virtual_machines" {
  type = map(object({
    name                = string
    resource_group_name = string
    subnet_resource_id  = string
    source_image_reference = object({
      publisher = string
      offer     = string
      sku       = string
      version   = string
    })

    location                            = optional(string, null)
    os_type                             = optional(string, "Linux")
    zone                                = optional(string, null)
    size                                = optional(string, "Standard_DC2as_v5")
    admin_username                      = optional(string, "azureuser")
    admin_password                      = optional(string, null)
    admin_ssh_public_key                = optional(string, null)
    secure_boot_enabled                 = optional(bool, true)
    vtpm_enabled                        = optional(bool, true)
    private_ip_address                  = optional(string, null)
    private_ip_address_allocation       = optional(string, "Dynamic")
    network_interface_name              = optional(string, null)
    accelerated_networking_enabled      = optional(bool, false)
    computer_name                       = optional(string, null)
    identity_type                       = optional(string, "None")
    user_assigned_identity_resource_ids = optional(set(string), [])
    tags                                = optional(map(string), null)
    backup_configuration = optional(object({
      recovery_vault_resource_group_name = string
      recovery_vault_name                = string
      backup_policy_resource_id          = string
      retain_backup_data_on_destroy      = optional(bool, true)
      include_disk_luns                  = optional(set(number), null)
      exclude_disk_luns                  = optional(set(number), null)
    }), null)
    data_disks = optional(map(object({
      name                      = optional(string, null)
      lun                       = number
      disk_size_gb              = number
      storage_account_type      = optional(string, "Premium_LRS")
      caching                   = optional(string, "ReadWrite")
      zone                      = optional(string, null)
      disk_encryption_set_id    = optional(string, null)
      write_accelerator_enabled = optional(bool, false)
      tags                      = optional(map(string), null)
    })), {})
    os_disk = optional(object({
      caching                          = optional(string, "ReadWrite")
      storage_account_type             = optional(string, "Premium_LRS")
      disk_size_gb                     = optional(number, null)
      security_encryption_type         = optional(string, "DiskWithVMGuestState")
      secure_vm_disk_encryption_set_id = optional(string, null)
    }), {})
  }))
  description = <<DESCRIPTION
Map of confidential virtual machine definitions for the pattern.

Keys identify VM instances and must be known at plan time. Values are objects:

- `name` - (Required) Name of the virtual machine.
- `resource_group_name` - (Required) Existing resource group name for the VM, NIC, and data disks.
- `subnet_resource_id` - (Required) Subnet resource ID used by the primary NIC IP configuration.
- `source_image_reference` - (Required) Source image reference for the virtual machine.
  - `publisher` - (Required) Image publisher.
  - `offer` - (Required) Image offer.
  - `sku` - (Required) Confidential-compute-compatible image SKU.
  - `version` - (Required) Image version or `latest`.
- `location` - (Optional) Region for the VM and NIC. If omitted, module-level `location` is used.
- `os_type` - (Optional) VM operating system type: `Linux` or `Windows`. Defaults to `Linux`.
- `zone` - (Optional) Availability zone for the virtual machine.
- `size` - (Optional) VM size. Defaults to `Standard_DC2as_v5`.
- `admin_username` - (Optional) Admin username. Defaults to `azureuser`.
- `admin_password` - (Optional) Admin password. Required for Windows. Optional for Linux when SSH key is provided.
- `admin_ssh_public_key` - (Optional) SSH public key for Linux.
- `secure_boot_enabled` - (Optional) Enable secure boot. Defaults to `true`.
- `vtpm_enabled` - (Optional) Enable vTPM. Defaults to `true`.
- `private_ip_address` - (Optional) Private IP for the primary NIC IP configuration. Supplying a value forces static allocation.
- `private_ip_address_allocation` - (Optional) `Dynamic` or `Static`. Defaults to `Dynamic`.
- `network_interface_name` - (Optional) NIC name. Defaults to `<name>-nic`.
- `accelerated_networking_enabled` - (Optional) Whether accelerated networking is enabled on the NIC. Defaults to `false`.
- `computer_name` - (Optional) OS hostname; when omitted, the provider uses the VM name subject to OS naming constraints.
- `identity_type` - (Optional) Case-sensitive managed identity type: `None`, `SystemAssigned`, `UserAssigned`, or `SystemAssigned, UserAssigned`. Defaults to `None`, which disables all VM identities. The combined mode accepts either order and optional spaces around the comma.
- `user_assigned_identity_resource_ids` - (Optional) User-assigned identity IDs, only used when `identity_type` includes `UserAssigned`.
- `tags` - (Optional) Tags applied to VM and NIC resources. If omitted, module-level `tags` is used. Maps replace rather than merge.
- `backup_configuration` - (Optional) Azure Backup configuration:
  - `recovery_vault_resource_group_name` - (Required) Resource group name of the Recovery Services vault.
  - `recovery_vault_name` - (Required) Name of the Recovery Services vault.
  - `backup_policy_resource_id` - (Required) Compatible backup policy resource ID to associate with the VM. Use an Enhanced (`V2`) policy when required by the VM configuration. For daily/weekly Enhanced policies, explicitly configure instant-restore retention shorter than vaulted retention. The module does not create or convert policies.
  - `retain_backup_data_on_destroy` - (Optional) Stop protection and retain recovery points when backup protection is destroyed. Defaults to `true`. Set to `false` to request deletion instead. Apply this setting before removing `backup_configuration`; destroy uses the previously applied value. Retained recovery points can continue to incur charges.
  - `include_disk_luns` - (Optional) Declared data-disk LUNs to include in backup. Mutually exclusive with `exclude_disk_luns`.
  - `exclude_disk_luns` - (Optional) Declared data-disk LUNs to exclude from backup. Mutually exclusive with `include_disk_luns`.
- `data_disks` - (Optional) Map of additional managed data disks (zero to many) created and attached to the VM:
  - `name` - (Optional) Managed disk name. Defaults to `<vm-name>-<disk-key>`.
  - `lun` - (Required) Data disk LUN between 0 and 63, unique within this VM.
  - `disk_size_gb` - (Required) Data disk size in GB.
  - `storage_account_type` - (Optional) Storage SKU. Defaults to `Premium_LRS`.
  - `caching` - (Optional) Host caching mode (`None`, `ReadOnly`, `ReadWrite`). Defaults to `ReadWrite`.
  - `zone` - (Optional) Availability zone for the managed disk. Does not inherit the VM zone.
  - `disk_encryption_set_id` - (Optional) Disk encryption set resource ID.
  - `write_accelerator_enabled` - (Optional) Enables write accelerator on the attachment. Defaults to `false`.
  - `tags` - (Optional) Tags for the data disk resource, replacing VM tags when supplied. Inherits VM tags when omitted; may be omitted at all levels.
- `os_disk` - (Optional) Confidential OS disk options:
  - `caching` - (Optional) OS disk caching type. Defaults to `ReadWrite`.
  - `storage_account_type` - (Optional) OS disk storage account type. Defaults to `Premium_LRS`.
  - `disk_size_gb` - (Optional) OS disk size in GB.
  - `security_encryption_type` - (Optional) Confidential OS disk encryption type: `VMGuestStateOnly` or `DiskWithVMGuestState`. Defaults to `DiskWithVMGuestState`.
  - `secure_vm_disk_encryption_set_id` - (Optional) Disk encryption set resource ID for confidential disk encryption with customer-managed keys.
DESCRIPTION
  nullable    = false

  validation {
    condition     = length(var.confidential_virtual_machines) > 0
    error_message = "confidential_virtual_machines must contain at least one virtual machine."
  }
  validation {
    condition = alltrue([
      for vm in values(var.confidential_virtual_machines) : vm.location != null || var.location != null
    ])
    error_message = "Each confidential virtual machine must define location or use the module-level location."
  }
  validation {
    condition = alltrue([
      for vm in values(var.confidential_virtual_machines) : contains(["linux", "windows"], lower(vm.os_type))
    ])
    error_message = "Each confidential_virtual_machines item must set os_type to either Linux or Windows."
  }
  validation {
    condition = alltrue([
      for vm in values(var.confidential_virtual_machines) : contains(
        ["None", "SystemAssigned", "UserAssigned", "SystemAssigned,UserAssigned", "UserAssigned,SystemAssigned"],
        replace(vm.identity_type, " ", "")
      )
    ])
    error_message = "Each identity_type must be None, SystemAssigned, UserAssigned, or \"SystemAssigned, UserAssigned\" (case-sensitive)."
  }
  validation {
    condition = alltrue([
      for vm in values(var.confidential_virtual_machines) : lower(vm.os_type) != "linux" || vm.admin_password != null || vm.admin_ssh_public_key != null
    ])
    error_message = "Linux confidential virtual machines require either admin_password or admin_ssh_public_key."
  }
  validation {
    condition = alltrue([
      for vm in values(var.confidential_virtual_machines) : lower(vm.os_type) != "windows" || vm.admin_password != null
    ])
    error_message = "Windows confidential virtual machines require admin_password."
  }
  validation {
    condition = alltrue([
      for vm in values(var.confidential_virtual_machines) : vm.private_ip_address != null || lower(vm.private_ip_address_allocation) != "static"
    ])
    error_message = "private_ip_address must be set when private_ip_address_allocation is Static."
  }
  validation {
    condition = alltrue([
      for vm in values(var.confidential_virtual_machines) : vm.os_disk.secure_vm_disk_encryption_set_id == null || vm.os_disk.security_encryption_type == "DiskWithVMGuestState"
    ])
    error_message = "os_disk.secure_vm_disk_encryption_set_id can only be used when os_disk.security_encryption_type is DiskWithVMGuestState."
  }
  validation {
    condition = alltrue([
      for vm in values(var.confidential_virtual_machines) : vm.os_disk.security_encryption_type == null || vm.vtpm_enabled
    ])
    error_message = "vtpm_enabled must be true when os_disk.security_encryption_type is set."
  }
  validation {
    condition = alltrue([
      for vm in values(var.confidential_virtual_machines) : vm.backup_configuration == null || vm.backup_configuration.include_disk_luns == null || vm.backup_configuration.exclude_disk_luns == null
    ])
    error_message = "backup_configuration.include_disk_luns and backup_configuration.exclude_disk_luns are mutually exclusive."
  }
  validation {
    condition = alltrue([
      for vm in values(var.confidential_virtual_machines) : vm.backup_configuration == null ? true : try(
        endswith(
          lower(provider::azapi::parse_resource_id("Microsoft.RecoveryServices/vaults/backupPolicies", vm.backup_configuration.backup_policy_resource_id).parent_id),
          lower("/resourceGroups/${vm.backup_configuration.recovery_vault_resource_group_name}/providers/Microsoft.RecoveryServices/vaults/${vm.backup_configuration.recovery_vault_name}")
        ),
        false
      )
    ])
    error_message = "Each backup_configuration.backup_policy_resource_id must be a VM backup policy ID in the specified Recovery Services vault and resource group."
  }
  validation {
    condition = alltrue([
      for vm in values(var.confidential_virtual_machines) : vm.backup_configuration == null || vm.backup_configuration.include_disk_luns == null || alltrue([
        for lun in vm.backup_configuration.include_disk_luns : contains([for disk in values(vm.data_disks) : disk.lun], lun)
      ])
    ])
    error_message = "Each backup_configuration.include_disk_luns entry must reference a LUN defined in data_disks."
  }
  validation {
    condition = alltrue([
      for vm in values(var.confidential_virtual_machines) : vm.backup_configuration == null || vm.backup_configuration.exclude_disk_luns == null || alltrue([
        for lun in vm.backup_configuration.exclude_disk_luns : contains([for disk in values(vm.data_disks) : disk.lun], lun)
      ])
    ])
    error_message = "Each backup_configuration.exclude_disk_luns entry must reference a LUN defined in data_disks."
  }
  validation {
    condition = alltrue([
      for vm in values(var.confidential_virtual_machines) : length(vm.data_disks) == length(distinct([for disk in values(vm.data_disks) : disk.lun]))
    ])
    error_message = "Each confidential virtual machine must use unique LUN values across its data_disks."
  }
  validation {
    condition = alltrue(flatten([
      for vm in values(var.confidential_virtual_machines) : [
        for disk in values(vm.data_disks) : disk.lun >= 0 && disk.lun <= 63
      ]
    ]))
    error_message = "Each data disk LUN must be between 0 and 63."
  }
  validation {
    condition = alltrue(flatten([
      for vm in values(var.confidential_virtual_machines) : [
        for disk in values(vm.data_disks) : contains(["none", "readonly", "readwrite"], lower(disk.caching))
      ]
    ]))
    error_message = "Each data disk caching value must be one of None, ReadOnly, or ReadWrite."
  }
}

variable "enable_telemetry" {
  type        = bool
  default     = true
  description = <<DESCRIPTION
This variable controls whether or not telemetry is enabled for the module.
For more information see <https://aka.ms/avm/telemetryinfo>.
If it is set to false, then no telemetry will be collected.
DESCRIPTION
  nullable    = false
}

variable "tags" {
  type        = map(string)
  default     = null
  description = "Default tags for VMs and NICs when VM-level tags are omitted. VM tags replace this map rather than merge with it. Data disks inherit VM tags unless disk-level tags are supplied. Tags may be omitted at all levels."
}

variable "ignore_body_changes" {
  type = object({
    compute_disks = optional(list(string), [])
    compute_virtual_machines = optional(object({
      maintenance_configuration_assignments = optional(list(string), [])
      authorization_locks                   = optional(list(string), [])
      authorization_role_assignments        = optional(list(string), [])
      insights_diagnostic_settings          = optional(list(string), [])
      network_network_interfaces            = optional(list(string), [])
      network_public_ip_addresses           = optional(list(string), [])
      compute_disks                         = optional(list(string), [])
      compute_virtual_machines              = optional(list(string), [])
      devtestlab_schedules                  = optional(list(string), [])
      recoveryservices_vaults_backupfabrics_protectioncontainers_protecteditems = optional(object({
        recoveryservices_vaults_backupfabrics_protectioncontainers_protecteditems = optional(list(string), [])
      }), {})
      compute_virtual_machines_extensions = optional(object({
        compute_virtual_machines_extensions = optional(list(string), [])
      }), {})
      compute_virtual_machines_run_commands = optional(object({
        compute_virtual_machines_run_commands = optional(list(string), [])
      }), {})
    }), {})
    recoveryservices_vaults_backupfabrics_protectioncontainers_protecteditems = optional(object({
      recoveryservices_vaults_backupfabrics_protectioncontainers_protecteditems = optional(list(string), [])
    }), {})
  })
  default     = {}
  description = <<DESCRIPTION
Body-relative paths to ignore, using dot notation. Changes take effect only after apply.
Configuration for an ignored path is not sent to Azure until the path is removed.

- `compute_disks` - Paths ignored on the pattern-managed data disks.
- `compute_virtual_machines` - Per-resource paths for the AVM VM module; the field names match its `ignore_body_changes` input.
- `recoveryservices_vaults_backupfabrics_protectioncontainers_protecteditems` - Overrides for the AVM backup child, which does not currently honor ignored paths for protected items.
DESCRIPTION
  nullable    = false
}

variable "resource_types" {
  type = object({
    compute_disks = optional(string, "Microsoft.Compute/disks@2025-01-02")
    compute_virtual_machines = optional(object({
      maintenance_configuration_assignments = optional(string)
      compute_disks                         = optional(string)
      compute_virtual_machines              = optional(string)
      authorization_locks                   = optional(string)
      authorization_role_assignments        = optional(string)
      insights_diagnostic_settings          = optional(string)
      network_network_interfaces            = optional(string)
      network_public_ip_addresses           = optional(string)
      devtestlab_schedules                  = optional(string)
      keyvault_vaults_secrets               = optional(string)
      recoveryservices_vaults_backupfabrics_protectioncontainers_protecteditems = optional(object({
        recoveryservices_vaults_backupfabrics_protectioncontainers_protecteditems = optional(string)
      }), {})
      compute_virtual_machines_extensions = optional(object({
        compute_virtual_machines_extensions = optional(string)
      }), {})
      compute_virtual_machines_run_commands = optional(object({
        compute_virtual_machines_run_commands = optional(string)
      }), {})
    }), {})
    recoveryservices_vaults_backupfabrics_protectioncontainers_protecteditems = optional(object({
      recoveryservices_vaults_backupfabrics_protectioncontainers_protecteditems = optional(string)
    }), {})
  })
  default     = {}
  description = <<DESCRIPTION
AzAPI resource type and API version overrides.

- `compute_disks` - Resource type and API version for pattern-managed data disks.
- `compute_virtual_machines` - Resource type and API version overrides matching the AVM VM module's `resource_types` input.
- `recoveryservices_vaults_backupfabrics_protectioncontainers_protecteditems` - Overrides for the AVM backup child. The identically named field within this object sets the API version for protected items.
DESCRIPTION
  nullable    = false
}

variable "retry" {
  type = object({
    error_message_regex  = optional(list(string))
    interval_seconds     = optional(number)
    max_interval_seconds = optional(number)
  })
  default     = null
  description = "Optional AzAPI retry settings: `error_message_regex` matches retryable errors, `interval_seconds` is the initial interval, and `max_interval_seconds` is the maximum interval."
}

variable "timeouts" {
  type = object({
    create = optional(string)
    read   = optional(string)
    update = optional(string)
    delete = optional(string)
  })
  default     = null
  description = "Optional AzAPI operation timeouts as duration strings (e.g. `30m`), keyed by `create`, `read`, `update`, or `delete`."
}
