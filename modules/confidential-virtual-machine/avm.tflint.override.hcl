# SFR4 requires nullable, optional location when it is used only for telemetry.
# VM resources use each VM's required location, not this telemetry-only input.
# Remove this exception when the managed rule supports SFR4's telemetry-only contract.
# https://azure.github.io/Azure-Verified-Modules/spec/SFR4/
rule "avm_interface_location" {
  enabled = false
}
