# terraform/bootstrap/gcp_wif/variables.tf

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region for state bucket and default resources"
  type        = string
  default     = "us-central1"
}

variable "github_org" {
  description = "GitHub organization or user that owns the infrastructure-automation repo"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name (used for WIF trust)"
  type        = string
  default     = "infrastructure-automation"
}

variable "state_bucket_name" {
  description = "GCS bucket name for Terraform state (defaults to {project_id}-tfstate)"
  type        = string
  default     = ""
}
