data "azurerm_log_analytics_workspace" "law" {
  name                = "${var.appName}-${var.location}-${var.environment}-law"
  resource_group_name = var.resource_group
}

# -------------------------
# Container Apps Environment
# -------------------------
resource "azurerm_container_app_environment" "cae" {
  name                       = "${var.appName}-${var.location}-${var.environment}-cae"
  location                   = var.location
  resource_group_name        = var.resource_group
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.law.id
    tags = {
    Environment = var.environment
    Owner       = var.owner
  }
  }