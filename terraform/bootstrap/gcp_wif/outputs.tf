# terraform/bootstrap/gcp_wif/outputs.tf
#
# Copy these values to your GitHub repository secrets:
#   GCP_WORKLOAD_IDENTITY_PROVIDER = workload_identity_provider
#   GCP_SERVICE_ACCOUNT            = service_account_email
#   GCP_STATE_BUCKET               = state_bucket_name

output "workload_identity_provider" {
  description = "Full resource name of the WIF provider (for google-github-actions/auth)"
  value       = google_iam_workload_identity_pool_provider.github.name
}

output "service_account_email" {
  description = "Service account email for GitHub Actions"
  value       = google_service_account.github_actions.email
}

output "state_bucket_name" {
  description = "GCS bucket for Terraform state"
  value       = google_storage_bucket.tfstate.name
}

output "workload_identity_pool_id" {
  description = "Workload Identity Pool ID"
  value       = google_iam_workload_identity_pool.github.workload_identity_pool_id
}
