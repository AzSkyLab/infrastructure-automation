# terraform/modules/cloud_run/outputs.tf

output "id" {
  description = "Cloud Run service ID"
  value       = google_cloud_run_v2_service.main.id
}

output "name" {
  description = "Cloud Run service name"
  value       = google_cloud_run_v2_service.main.name
}

output "uri" {
  description = "Cloud Run service URL (https://*.run.app)"
  value       = google_cloud_run_v2_service.main.uri
}

output "location" {
  description = "Cloud Run service location"
  value       = google_cloud_run_v2_service.main.location
}

output "project" {
  description = "GCP project ID"
  value       = google_cloud_run_v2_service.main.project
}

output "revision" {
  description = "Latest ready revision name"
  value       = google_cloud_run_v2_service.main.latest_ready_revision
}
