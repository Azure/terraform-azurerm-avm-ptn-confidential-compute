locals {
  confidential_virtual_machines = {
    for key, value in var.confidential_virtual_machines : key => merge(value, {
      location = coalesce(value.location, var.location)
      tags     = value.tags != null ? value.tags : var.tags
    })
  }

  telemetry_location = var.location != null ? var.location : try(values(local.confidential_virtual_machines)[0].location, null)
}
