provider "google" {
  project                     = var.project_id
  region                      = var.region
  impersonate_service_account = local.have_impersonator ? local.impersonator_sa : null
}

terraform {
  backend "gcs" {
    prefix = "terraform/state"
  }
}

data "google_project" "this" {
  project_id = var.project_id
}

locals {
  impersonator_sa   = trimspace(var.impersonate_service_account)
  have_impersonator = length(local.impersonator_sa) > 0

  gh_repo          = trimspace(var.github_repository)
  have_wif_binding = local.have_impersonator && length(local.gh_repo) > 0
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
  for_each = local.have_impersonator ? toset([
    "roles/run.admin",
    "roles/artifactregistry.admin",
    "roles/iam.serviceAccountUser",
    "roles/serviceusage.serviceUsageAdmin",
    "roles/iam.serviceAccountTokenCreator",
  ]) : toset([])

  project = var.project_id
  role    = each.key
  member  = "serviceAccount:${local.impersonator_sa}"
}

# Workload Identity Pool for GitHub Actions
resource "google_iam_workload_identity_pool" "github" {
  project                   = data.google_project.this.number
  workload_identity_pool_id = "github-actions-pool"
  display_name              = "GitHub Actions Pool"
}

# Workload Identity Pool Provider for GitHub OIDC
resource "google_iam_workload_identity_pool_provider" "github" {
  project                            = data.google_project.this.number
  workload_identity_pool_id          = data.google_iam_workload_identity_pool.github.workload_identity_pool_id
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

# WIF can impersonate the SA (only when both are set)
resource "google_service_account_iam_member" "github_impersonate" {
  count              = local.have_wif_binding ? 1 : 0
  service_account_id = "projects/${var.project_id}/serviceAccounts/${local.impersonator_sa}"
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/projects/${data.google_project.this.number}/locations/global/workloadIdentityPools/github-actions-pool/attribute.repository/${local.gh_repo}"
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
