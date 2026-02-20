variable "location" {
  description = "Azure region where the Resource Group will be created."
  type        = string
  default     = "West US 2"
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