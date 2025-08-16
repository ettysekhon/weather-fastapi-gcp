provider "google" {
  project                     = var.project_id
  region                      = var.region
  impersonate_service_account = var.impersonate_service_account != "" ? var.impersonate_service_account : null
}

data "google_project" "this" {
  project_id = var.project_id
}

# Enable required APIs
resource "google_project_service" "required" {
  for_each = toset([
    "run.googleapis.com",
    "artifactregistry.googleapis.com",
    "iamcredentials.googleapis.com",
    "iam.googleapis.com",
    "secretmanager.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "serviceusage.googleapis.com"
  ])
  project                    = var.project_id
  service                    = each.key
  disable_on_destroy         = false
  disable_dependent_services = false
}

# Artifact Registry
resource "google_artifact_registry_repository" "repo" {
  project       = var.project_id
  location      = var.region
  repository_id = var.repo_id
  description   = "Docker images for Weather API"
  format        = "DOCKER"
  depends_on    = [google_project_service.required]
}

# Runtime Service Account for Cloud Run
resource "google_service_account" "runtime" {
  project      = var.project_id
  account_id   = "${var.service_name}-runtime"
  display_name = "${var.service_name} runtime"
}

# Deployer Service Account for GitHub Actions (optional)
resource "google_service_account" "deployer" {
  count        = var.manage_deployer_sa ? 1 : 0
  project      = var.project_id
  account_id   = "${var.service_name}-deployer"
  display_name = "${var.service_name} deployer"
}

# IAM roles for deployer SA (using impersonate_service_account)
resource "google_project_iam_member" "deployer_iam_roles" {
  for_each = toset([
    "roles/run.admin",
    "roles/artifactregistry.admin",
    "roles/iam.serviceAccountUser",
    "roles/serviceusage.serviceUsageAdmin",
  ])
  project = var.project_id
  role    = each.key
  member  = "serviceAccount:${var.impersonate_service_account}"
}

# Workload Identity Pool for GitHub Actions
resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "github-actions-pool"
  display_name              = "GitHub Actions Pool"
}

# Workload Identity Pool Provider for GitHub OIDC
resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider"
  display_name                       = "GitHub Provider"
  attribute_mapping = {
    "google.subject"  = "assertion.sub"
    "attribute.actor" = "assertion.actor"
    "attribute.repo"  = "assertion.repository"
  }
  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# Allow GitHub Actions WIF to impersonate the deployer SA
resource "google_service_account_iam_member" "github_impersonate" {
  service_account_id = "projects/${var.project_id}/serviceAccounts/${var.impersonate_service_account}"
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/projects/${data.google_project.this.number}/locations/global/workloadIdentityPools/github-actions-pool/attribute.repository/${var.github_repository}"
}

# Cloud Run
locals {
  image_url = "${var.region}-docker.pkg.dev/${var.project_id}/${var.repo_id}/${var.service_name}:${var.image_tag}"
}

resource "google_cloud_run_v2_service" "service" {
  name                = var.service_name
  location            = var.region
  ingress             = "INGRESS_TRAFFIC_ALL"
  deletion_protection = false

  template {
    service_account = google_service_account.runtime.email

    containers {
      image = local.image_url

      ports {
        container_port = 8080
      }
    }
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }

  depends_on = [google_project_service.required]
}

# Public access (if allow_unauthenticated=true)
resource "google_cloud_run_v2_service_iam_member" "public" {
  count    = var.allow_unauthenticated ? 1 : 0
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.service.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
