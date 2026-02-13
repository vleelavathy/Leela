

data "azurerm_container_environment" "cae" {
  name                = "${var.appName}-${var.location}-${var.environment}-cae"
  resource_group_name = var.resource_group
}

# -------------------------
# Container App (public ingress)
# -------------------------
resource "azurerm_container_app" "app" {
  name                         = "${var.appName}-${var.location}-${var.environment}-aca-${var.index}"
  container_app_environment_id = data.azurerm_container_environment.cae.id
  resource_group_name          = var.resource_group
  revision_mode                = "Single"

  template {
    container {
      name   = "${var.appName}-${var.location}-${var.environment}-container"
      image  = var.container_image
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
    target_port      = var.container_port
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
