# terraform/patterns/cloud_run/variables.tf

# --- Enterprise metadata (mirrors Azure pattern conventions) ---

variable "project" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment (prototype, dev, tst, stg, prd)"
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

variable "business_unit" {
  description = "Business unit for labeling"
  type        = string
  default     = ""
}

variable "application_id" {
  description = "Unique application identifier"
  type        = string
  default     = ""
}

variable "application_name" {
  description = "Human-readable application name"
  type        = string
  default     = ""
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
  default     = []
}

# --- GCP-specific ---

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

# --- Cloud Run configuration ---

variable "container_image" {
  description = "Container image to deploy"
  type        = string
  default     = "us-docker.pkg.dev/cloudrun/container/hello"
}

variable "cpu" {
  description = "CPU allocation (1, 2, 4, or 8)"
  type        = string
  default     = "1"
}

variable "memory" {
  description = "Memory allocation (e.g., 512Mi, 1Gi)"
  type        = string
  default     = "512Mi"
}

variable "min_instance_count" {
  description = "Minimum instances (0 for scale-to-zero)"
  type        = number
  default     = 0
}

variable "max_instance_count" {
  description = "Maximum instances"
  type        = number
  default     = 1
}

variable "container_port" {
  description = "Container port for ingress"
  type        = number
  default     = 8080
}

variable "ingress" {
  description = "Ingress traffic setting"
  type        = string
  default     = "INGRESS_TRAFFIC_ALL"
}

variable "allow_unauthenticated" {
  description = "Allow unauthenticated (public) access"
  type        = bool
  default     = false
}

variable "environment_variables" {
  description = "Environment variables for the container"
  type        = map(string)
  default     = {}
}
