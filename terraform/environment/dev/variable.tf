variable "location" {
  description = "Azure region where the Resource Group will be created."
  type        = string
  default     = "East US"
}

variable "environment" {
  description = "Environment tag for the Resource Group."
  type        = string
  default     = "Dev"
}

variable "owner" {
  description = "Owner tag for the Resource Group."
  type        = string
  default     = "Admin"
}

variable "appName" {
    description = "appName"
    type = string
}

variable "resource_group" {
    description = "resource_group"
    type = string
}

variable "environment_variables" {
	description = "Map of environment variables to inject into the container"
	type        = map(string)
	default     = {}
}
