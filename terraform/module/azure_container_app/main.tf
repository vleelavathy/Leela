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

# -------------------------
# Container Apps Environment
# -------------------------
resource "azurerm_container_app_environment" "cae" {
  name                       = "${var.appName}${var.location}${var.environment}cae"
  location                   = var.location
  resource_group_name        = var.resource_group
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id
    tags = {
    Environment = var.environment
    Owner       = var.owner
  }
  }

# -------------------------
# Container App (public ingress)
# -------------------------
resource "azurerm_container_app" "app" {
  name                         = "${var.appName}-${var.location}-${var.environment}-aca"
  container_app_environment_id = azurerm_container_app_environment.cae.id
  resource_group_name          = var.resource_group
  revision_mode                = "Single"

  template {
    container {
      name   = "${var.appName}-${var.location}-${var.environment}-container"
      image  = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"    
      cpu    = 2
      memory = "4Gi"

      # Optional: pass env vars
      dynamic "env" {
        for_each = var.environment_variables
        content {
          name  = env.key
          value = env.value
        }
      }

    }

    min_replicas = 1
    max_replicas = 2
  }

  ingress {
    external_enabled = true
    target_port      = 80
    transport        = "auto"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }
tags = {
    Environment = var.environment
    Owner       = var.owner
  }
}
