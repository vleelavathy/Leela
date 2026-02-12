# -------------------------
# Log Analytics (required for ACA env)
# -------------------------
resource "azurerm_log_analytics_workspace" "law" {
  name                = "${var.appName}-${var.location}-${var.environment}-law"
  location            = var.location
  resource_group_name = var.resource_group
  sku                 = "PerGB2018"
  retention_in_days   = 30
    tags = {
    Environment = var.environment
    Owner       = var.owner
  }
}