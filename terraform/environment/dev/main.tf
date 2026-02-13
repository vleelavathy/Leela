module "resource_group" {
  source = "../../module/resource_group"
  location = var.location
  owner = var.owner
  environment = var.environment
  appName = var.appName
}


module "storage_account" {
  source = "../../module/storage_account"
  location = var.location
  owner = var.owner
  environment = var.environment
  appName = var.appName
  resource_group = var.resource_group
}

module "vnet" {
  source = "../../module/vnet_subnet"
  location = var.location
  owner = var.owner
  environment = var.environment
  appName = var.appName
  resource_group = var.resource_group
}

module "aca-01" {
  source = "../../module/azure_container_app"
  location = var.location
  environment_variables = var.environment_variables
  environment = var.environment
  appName = var.appName
  resource_group = var.resource_group
  index = 01
}

module "aca-02" {
  source = "../../module/azure_container_app"
  location = var.location
  environment_variables = var.environment_variables
  environment = var.environment
  appName = var.appName
  resource_group = var.resource_group
  index = 02
}

# module "acr" {
#   source = "../../module/azure_container_registry"
#   location = var.location
#   environment = var.environment
#   appName = var.appName
#   resource_group = var.resource_group
# }


module "azurerm_log_analytics_workspace"{
   source = "../../module/azure_log_analytics"
   location = var.location
   environment = var.environment
   appName = var.appName
   resource_group = var.resource_group
}

module "azurerm_container_app_environment" {
  source = "../../module/azure_container_env"
  location = var.location
  environment = var.environment
  appName = var.appName
  resource_group = var.resource_group 
}