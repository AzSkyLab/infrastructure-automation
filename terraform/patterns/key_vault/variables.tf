# terraform/patterns/key_vault/variables.tf

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
  description = "Resource name suffix"
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

variable "sku_name" {
  description = "Key Vault SKU (standard or premium)"
  type        = string
  default     = "standard"

  validation {
    condition     = contains(["standard", "premium"], var.sku_name)
    error_message = "SKU must be 'standard' or 'premium'."
  }
}

variable "purge_protection_enabled" {
  description = "Enable purge protection (recommended for production)"
  type        = bool
  default     = true
}

variable "soft_delete_retention_days" {
  description = "Soft delete retention in days (7-90)"
  type        = number
  default     = 7
}
