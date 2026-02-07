resource "azurerm_resource_group" "rg1" {
  name     = "${var.appName}-${var.location}-${var.environment}-rg"
  location = var.location
  tags = {
    Environment = var.environment
    Owner       = var.owner
  }
}


