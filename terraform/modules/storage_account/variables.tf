# terraform/modules/storage_account/variables.tf

variable "name" {
  description = "Storage account name (3-24 chars, lowercase alphanumeric)"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "account_tier" {
  description = "Storage account tier (Standard or Premium)"
  type        = string
  default     = "Standard"
}

variable "replication_type" {
  description = "Replication type (LRS, GRS, ZRS, RAGRS)"
  type        = string
  default     = "LRS"
}

variable "access_tier" {
  description = "Access tier (Hot, Cool)"
  type        = string
  default     = "Hot"
}

variable "enable_versioning" {
  description = "Enable blob versioning"
  type        = bool
  default     = false
}

variable "soft_delete_days" {
  description = "Soft delete retention days (0 to disable)"
  type        = number
  default     = 0
}

variable "containers" {
  description = "List of blob container names to create"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
