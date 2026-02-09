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