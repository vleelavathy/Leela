resource "azurerm_service_plan" "plan" {
  name                = "${var.appName}-${var.environment}-plan"
  resource_group_name = var.resource_group
  location            = var.location
  os_type             = "Linux"
  sku_name            = "F1"
}

resource "azurerm_linux_web_app" "web" {
  name                = "${var.appName}-${var.environment}-web"
  resource_group_name =  var.resource_group
  location            =  var.location
  service_plan_id     = azurerm_service_plan.plan.id

  site_config { always_on = false }
}

output "webapp_name" { value = azurerm_linux_web_app.web.name }
output "resource_group_name" { value = var.resource_group }