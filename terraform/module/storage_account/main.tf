
resource "azurerm_storage_account" "storage_act" {
  name                     ="${var.location}${var.environment}storageact"
  resource_group_name      = var.resource_group
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "GRS"

  tags = {
    environment = "stg"
  }
}

resource "azurerm_storage_container" "example" {
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.storage_act.id
  container_access_type = "private"
}