terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "4.58.0"
    }
  }
}

provider "azurerm" {
  features { }
  subscription_id = "df007fd5-0354-490e-876c-f6f25f3d633d"
  tenant_id = "eb0342d5-f6d1-471d-bad9-37ffb39efcef"
}