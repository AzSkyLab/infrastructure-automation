# terraform/modules/naming/variables.tf

variable "project" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
}

variable "resource_type" {
  description = "Type of resource to generate name for"
  type        = string
}

variable "name" {
  description = "Resource name suffix"
  type        = string
}

variable "business_unit" {
  description = "Business unit for tagging"
  type        = string
  default     = ""
}

variable "pattern_name" {
  description = "Pattern name for unique resource group naming"
  type        = string
  default     = ""
}

variable "application_id" {
  description = "Unique application identifier for tagging"
  type        = string
  default     = ""
}

variable "application_name" {
  description = "Human-readable application name for tagging"
  type        = string
  default     = ""
}

variable "tier" {
  description = "Application tier (1-4) driving HA/DR decisions"
  type        = number
  default     = 4

  validation {
    condition     = var.tier >= 1 && var.tier <= 4
    error_message = "Tier must be between 1 and 4."
  }
}

variable "cost_center" {
  description = "Billing cost center for tagging"
  type        = string
  default     = ""
}
