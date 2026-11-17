module "confidential_virtual_machine" {
  source = "./modules/confidential-virtual-machine"

  confidential_virtual_machines = local.confidential_virtual_machines
  enable_telemetry              = var.enable_telemetry
  location                      = local.telemetry_location
}
