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
