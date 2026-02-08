
terraform {
  backend "azurerm" {
    resource_group_name  = "le-app-westus2-stg-rg"
    storage_account_name = "westus2stgstorageact"
    container_name       = "tfstate"
    key                  = "stg/dev_env.tfstate"
  }
}