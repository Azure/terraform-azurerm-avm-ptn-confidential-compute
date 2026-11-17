variable "admin_password" {
  type        = string
  description = "Administrator password for the Windows VM. Supply securely at runtime; Terraform stores it in state."
  sensitive   = true
  nullable    = false

  validation {
    condition = (
      length(var.admin_password) >= 12 &&
      length(var.admin_password) <= 123 &&
      sum([for pattern in ["[a-z]", "[A-Z]", "[0-9]", "[^a-zA-Z0-9]"] : length(regexall(pattern, var.admin_password)) > 0 ? 1 : 0]) >= 3
    )
    error_message = "The administrator password must contain 12-123 characters and at least three of: lowercase, uppercase, digits, and special characters."
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
}

variable "location" {
  type        = string
  default     = "eastus"
  description = "The Azure region for this module's resources or telemetry deployment."
  nullable    = false
}
