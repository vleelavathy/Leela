
# App Service Plan (Linux)
resource "azurerm_service_plan" "plan" {
  name                = "${var.appName}-plan"
  resource_group_name = var.resource_group
  location            = var.location

  os_type  = "Linux"
  sku_name = "B1" # cheap for lab. Use S1/P1v3 for prod
}

# Linux Web App
resource "azurerm_linux_web_app" "webapp" {
  name                = var.appName
  resource_group_name = var.resource_group
  location            = var.location
  service_plan_id     = azurerm_service_plan.plan.id

  https_only = true

  identity {
    type = "SystemAssigned"
  }

  site_config {
    always_on = true

    # Choose one runtime. Example: .NET 8
    application_stack {
      dotnet_version = "8.0"
    }

    # If you want Node instead, comment above and use:
    # application_stack { node_version = "20-lts" }
  }

  app_settings = {
    "ENVIRONMENT" = var.environment
    "OWNER"       = var.owner
  }

  tags = {
    Owner       = var.owner
    Environment = var.environment
  }
}

resource "azurerm_windows_web_app" "webapp" {
  name                = var.appName
  resource_group_name = var.resource_group
  location            = var.location
  service_plan_id     = azurerm_service_plan.plan.id

  https_only = true

  site_config {
    always_on = false
  }

  app_settings = {
    "ENVIRONMENT" = var.environment
  }
}