module "storage_account" {
  source = "../../../module/virtualmachine"
  location = var.location
  owner = var.owner
  environment = var.environment
  appName = var.appName
  resource_group = var.resource_group
}