terraform {
  required_version = ">= 1.5.0"

  required_providers {
    # TODO: Ensure all required providers are listed here and the version property includes a constraint on the maximum major version.
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.4"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.76"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}
