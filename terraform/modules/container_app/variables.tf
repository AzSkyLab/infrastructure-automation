# terraform/modules/container_app/variables.tf

variable "name" {
  description = "Container App name"
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

variable "container_app_environment_id" {
  description = "Existing Container App Environment ID. If null, a new one is created."
  type        = string
  default     = null
}

variable "environment_name" {
  description = "Container App Environment name (used when creating new environment)"
  type        = string
  default     = null
}

variable "revision_mode" {
  description = "Revision mode (Single or Multiple)"
  type        = string
  default     = "Single"
}

variable "container_name" {
  description = "Container name (defaults to app name)"
  type        = string
  default     = null
}

variable "container_image" {
  description = "Container image (e.g., mcr.microsoft.com/hello-world-k8s-helm:latest)"
  type        = string
  default     = "mcr.microsoft.com/k8se/quickstart:latest"
}

variable "cpu" {
  description = "CPU cores (e.g., 0.25, 0.5, 1.0)"
  type        = number
  default     = 0.25
}

variable "memory" {
  description = "Memory (e.g., 0.5Gi, 1Gi)"
  type        = string
  default     = "0.5Gi"
}

variable "min_replicas" {
  description = "Minimum number of replicas"
  type        = number
  default     = 0
}

variable "max_replicas" {
  description = "Maximum number of replicas"
  type        = number
  default     = 1
}

variable "enable_ingress" {
  description = "Enable HTTP ingress"
  type        = bool
  default     = true
}

variable "external_ingress" {
  description = "Allow external (internet) ingress"
  type        = bool
  default     = true
}

variable "target_port" {
  description = "Target port for ingress"
  type        = number
  default     = 80
}

variable "environment_variables" {
  description = "Environment variables for the container"
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
