module "vnet" {
  source = "../../module/vnet_subnet"
  location = var.location
  owner = var.owner
  environment = var.environment
  appName = var.appName
  resource_group = var.resource_group
}

