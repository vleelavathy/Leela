
resource "azurerm_virtual_network" "vnet1" {
  name     = "${var.appName}-${var.location}-${var.environment}-vnet"
  location            = var.location
  resource_group_name = var.resource_group
  address_space       = ["10.0.0.0/16"]
  dns_servers         = ["10.0.0.4", "10.0.0.5"]

  subnet {
    name             = "subnet1"
    address_prefixes = ["10.0.1.0/24"]
  }

  subnet {
    name             = "subnet2"
    address_prefixes = ["10.0.2.0/24"]
    }

  subnet {
    name             = "subnet3"
    address_prefixes = ["10.0.3.0/24"]
   }

  tags = {
    Environment = var.environment
    Owner       = var.owner
  }
}

