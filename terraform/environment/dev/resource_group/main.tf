module "resource_group" {
  source = "../../../module/resource_group"
  location = var.location
  owner = var.owner
  environment = var.environment
  appName = var.appName
}