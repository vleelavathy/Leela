variable "appName" {
	description = "Short name for the application (used in resource names)"
	type        = string
}

variable "location" {
	description = "Azure region to deploy into"
	type        = string
	default     = "westus2"
}

variable "environment" {
	description = "Deployment environment (dev, stg, prd)"
	type        = string
	default     = "dev"
}

variable "resource_group" {
	description = "Name of the resource group to deploy into"
	type        = string
}

variable "environment_variables" {
	description = "Map of environment variables to inject into the container"
	type        = map(string)
	default     = {}
}

