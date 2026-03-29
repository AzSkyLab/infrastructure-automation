# terraform/bootstrap/gcp_wif/main.tf
#
# One-time bootstrap: creates GCP Workload Identity Federation resources,
# a service account for GitHub Actions, and a GCS bucket for Terraform state.
#
# Run locally with gcloud auth:
#   gcloud auth application-default login
#   terraform init
#   terraform apply -var="project_id=my-project" -var="github_org=my-org"

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }

  # Local backend — this bootstrap creates the GCS bucket, so it can't use it
  backend "local" {}
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# --- Enable required APIs ---

resource "google_project_service" "apis" {
  for_each = toset([
    "run.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "sts.googleapis.com",
  ])

  project                    = var.project_id
  service                    = each.value
  disable_dependent_services = false
  disable_on_destroy         = false
}

# --- GCS bucket for Terraform state ---

resource "google_storage_bucket" "tfstate" {
  name     = var.state_bucket_name != "" ? var.state_bucket_name : "${var.project_id}-tfstate"
  location = var.region
  project  = var.project_id

  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }

  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      num_newer_versions = 30
    }
  }

  labels = {
    managed-by = "terraform"
    purpose    = "terraform-state"
  }
}

# --- Workload Identity Pool ---

resource "google_iam_workload_identity_pool" "github" {
  project                   = var.project_id
  workload_identity_pool_id = "github-actions"
  display_name              = "GitHub Actions"
  description               = "Workload Identity Pool for GitHub Actions OIDC"

  depends_on = [google_project_service.apis["iam.googleapis.com"]]
}

# --- Workload Identity Provider (GitHub OIDC) ---

resource "google_iam_workload_identity_pool_provider" "github" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-oidc"
  display_name                       = "GitHub OIDC"
  description                        = "OIDC provider for GitHub Actions"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.actor"      = "assertion.actor"
    "attribute.repository" = "assertion.repository"
    "attribute.ref"        = "assertion.ref"
  }

  attribute_condition = "assertion.repository_owner == '${var.github_org}'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# --- Service Account for GitHub Actions ---

resource "google_service_account" "github_actions" {
  project      = var.project_id
  account_id   = "github-actions-cloudrun"
  display_name = "GitHub Actions - Cloud Run"
  description  = "Service account for GitHub Actions to deploy Cloud Run via WIF"

  depends_on = [google_project_service.apis["iam.googleapis.com"]]
}

# --- IAM roles for the service account ---

resource "google_project_iam_member" "sa_roles" {
  for_each = toset([
    "roles/run.admin",
    "roles/iam.serviceAccountUser",
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.github_actions.email}"
}

# Storage admin scoped to the state bucket only
resource "google_storage_bucket_iam_member" "sa_state_access" {
  bucket = google_storage_bucket.tfstate.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.github_actions.email}"
}

# --- WIF: allow GitHub repo to impersonate the service account ---

resource "google_service_account_iam_member" "wif_binding" {
  service_account_id = google_service_account.github_actions.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_org}/${var.github_repo}"
}
