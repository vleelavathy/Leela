# -------------------------
# Azure Container Registry
# -------------------------
resource "azurerm_container_registry" "acr" {
  name                       = "${var.location}${var.environment}acr"
  resource_group_name = var.resource_group
  location            = var.location

  sku           = "Standard"
  admin_enabled = true

  public_network_access_enabled = true

  identity {
    type = "SystemAssigned"
  }

tags = {
    Environment = var.environment
    Owner       = var.owner
  }
}
