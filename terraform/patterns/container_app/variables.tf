# terraform/patterns/container_app/variables.tf

variable "project" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
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

variable "owners" {
  description = "List of owner email addresses"
  type        = list(string)
}

variable "container_app_environment_id" {
  description = "Existing Container App Environment ID (creates new if null)"
  type        = string
  default     = null
}

variable "container_image" {
  description = "Container image"
  type        = string
  default     = "mcr.microsoft.com/k8se/quickstart:latest"
}

variable "cpu" {
  description = "CPU cores"
  type        = number
  default     = 0.25
}

variable "memory" {
  description = "Memory (e.g., 0.5Gi)"
  type        = string
  default     = "0.5Gi"
}

variable "min_replicas" {
  description = "Minimum replicas"
  type        = number
  default     = 0
}

variable "max_replicas" {
  description = "Maximum replicas"
  type        = number
  default     = 1
}

variable "enable_ingress" {
  description = "Enable HTTP ingress"
  type        = bool
  default     = true
}

variable "external_ingress" {
  description = "Allow external ingress"
  type        = bool
  default     = true
}

variable "target_port" {
  description = "Target port"
  type        = number
  default     = 80
}

variable "environment_variables" {
  description = "Environment variables for the container"
  type        = map(string)
  default     = {}
}

variable "enable_diagnostics" {
  description = "Enable diagnostic settings"
  type        = bool
  default     = false
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID for diagnostics"
  type        = string
  default     = ""
}
