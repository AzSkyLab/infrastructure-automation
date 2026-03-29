# terraform/patterns/cloud_run/main.tf
# Cloud Run pattern: GCP Cloud Run service with enterprise labels

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }

  backend "gcs" {}
}

provider "google" {
  project = var.project_id
  region  = var.region
}

locals {
  # GCP labels: lowercase keys, max 63 char values, no spaces
  labels = {
    application-id   = lower(replace(var.application_id, " ", "-"))
    application-name = lower(replace(var.application_name, " ", "-"))
    environment      = var.environment
    business-unit    = lower(replace(var.business_unit, " ", "-"))
    tier             = tostring(var.tier)
    cost-center      = lower(replace(var.cost_center, " ", "-"))
    managed-by       = "terraform"
    project          = lower(replace(var.project, " ", "-"))
  }
}

module "cloud_run" {
  source = "github.com/AzSkyLab/terraform-google-cloud-run?ref=v1.0.0"

  name                  = var.name
  project_id            = var.project_id
  region                = var.region
  container_image       = var.container_image
  cpu                   = var.cpu
  memory                = var.memory
  min_instance_count    = var.min_instance_count
  max_instance_count    = var.max_instance_count
  container_port        = var.container_port
  ingress               = var.ingress
  allow_unauthenticated = var.allow_unauthenticated
  environment_variables = var.environment_variables
  labels                = local.labels
}
