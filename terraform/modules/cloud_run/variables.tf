# terraform/modules/cloud_run/variables.tf

variable "name" {
  description = "Cloud Run service name"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,47}[a-z0-9]$", var.name))
    error_message = "Cloud Run service name must be lowercase alphanumeric with hyphens, 2-49 chars."
  }
}

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region (e.g., us-central1)"
  type        = string
}

variable "container_image" {
  description = "Container image to deploy"
  type        = string
  default     = "us-docker.pkg.dev/cloudrun/container/hello"
}

variable "cpu" {
  description = "CPU allocation (e.g., 1, 2, 4, 8)"
  type        = string
  default     = "1"

  validation {
    condition     = contains(["1", "2", "4", "8"], var.cpu)
    error_message = "CPU must be one of: 1, 2, 4, 8."
  }
}

variable "memory" {
  description = "Memory allocation (e.g., 512Mi, 1Gi, 2Gi)"
  type        = string
  default     = "512Mi"

  validation {
    condition     = can(regex("^[0-9]+(Mi|Gi)$", var.memory))
    error_message = "Memory must be in Mi or Gi format (e.g., 512Mi, 1Gi, 2Gi)."
  }
}

variable "min_instance_count" {
  description = "Minimum number of instances (0 for scale-to-zero)"
  type        = number
  default     = 0

  validation {
    condition     = var.min_instance_count >= 0 && var.min_instance_count <= 100
    error_message = "Min instance count must be between 0 and 100."
  }
}

variable "max_instance_count" {
  description = "Maximum number of instances"
  type        = number
  default     = 1

  validation {
    condition     = var.max_instance_count >= 1 && var.max_instance_count <= 100
    error_message = "Max instance count must be between 1 and 100."
  }
}

variable "container_port" {
  description = "Container port for ingress"
  type        = number
  default     = 8080

  validation {
    condition     = var.container_port >= 1 && var.container_port <= 65535
    error_message = "Container port must be between 1 and 65535."
  }
}

variable "ingress" {
  description = "Ingress traffic setting"
  type        = string
  default     = "INGRESS_TRAFFIC_ALL"

  validation {
    condition     = contains(["INGRESS_TRAFFIC_ALL", "INGRESS_TRAFFIC_INTERNAL_ONLY", "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"], var.ingress)
    error_message = "Ingress must be one of: INGRESS_TRAFFIC_ALL, INGRESS_TRAFFIC_INTERNAL_ONLY, INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER."
  }
}

variable "allow_unauthenticated" {
  description = "Allow unauthenticated (public) access via IAM"
  type        = bool
  default     = false
}

variable "environment_variables" {
  description = "Environment variables for the container"
  type        = map(string)
  default     = {}
}

variable "labels" {
  description = "Resource labels (GCP equivalent of Azure tags)"
  type        = map(string)
  default     = {}
}
