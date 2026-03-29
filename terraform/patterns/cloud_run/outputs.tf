# terraform/patterns/cloud_run/outputs.tf

output "cloud_run_id" {
  description = "Cloud Run service ID"
  value       = module.cloud_run.id
}

output "cloud_run_name" {
  description = "Cloud Run service name"
  value       = module.cloud_run.name
}

output "cloud_run_uri" {
  description = "Cloud Run service URL"
  value       = module.cloud_run.uri
}

output "cloud_run_location" {
  description = "Cloud Run service location"
  value       = module.cloud_run.location
}

output "cloud_run_project" {
  description = "GCP project ID"
  value       = module.cloud_run.project
}

output "cloud_run_revision" {
  description = "Latest ready revision name"
  value       = module.cloud_run.revision
}
