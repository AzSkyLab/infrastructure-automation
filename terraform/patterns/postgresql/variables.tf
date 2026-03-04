# terraform/patterns/postgresql/variables.tf

variable "project" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["prototype", "dev", "tst", "stg", "prd"], var.environment)
    error_message = "Environment must be 'prototype', 'dev', 'tst', 'stg', or 'prd'."
  }
}

variable "name" {
  description = "Resource name suffix (also used as database name)"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "eastus"
}

variable "business_unit" {
  description = "Business unit for tagging"
  type        = string
  default     = ""
}

variable "application_id" {
  description = "Unique application identifier"
  type        = string
}

variable "application_name" {
  description = "Human-readable application name"
  type        = string
}

variable "tier" {
  description = "Application tier (1-4)"
  type        = number
  default     = 4

  validation {
    condition     = var.tier >= 1 && var.tier <= 4
    error_message = "Tier must be between 1 and 4."
  }
}

variable "cost_center" {
  description = "Billing cost center"
  type        = string
  default     = ""
}

variable "owners" {
  description = "List of owner email addresses"
  type        = list(string)

  validation {
    condition     = length(var.owners) > 0
    error_message = "At least one owner email is required."
  }
}

variable "postgresql_version" {
  description = "PostgreSQL version"
  type        = string
  default     = "16"

  validation {
    condition     = contains(["13", "14", "15", "16", "17"], var.postgresql_version)
    error_message = "PostgreSQL version must be one of: 13, 14, 15, 16, 17."
  }
}

variable "sku_name" {
  description = "PostgreSQL SKU (e.g., B_Standard_B1ms, GP_Standard_D2s_v3)"
  type        = string
  default     = "B_Standard_B1ms"
}

variable "storage_mb" {
  description = "Storage size in MB"
  type        = number
  default     = 32768
}

variable "backup_retention_days" {
  description = "Backup retention in days"
  type        = number
  default     = 7
}

variable "geo_redundant_backup" {
  description = "Enable geo-redundant backups"
  type        = bool
  default     = false
}
