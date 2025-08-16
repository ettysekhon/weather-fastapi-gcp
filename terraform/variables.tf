variable "project_id" {
  description = "GCP project ID"
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "project_id must be a valid GCP project ID (lowercase, 6–30 chars, start with letter)."
  }
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
  validation {
    condition     = can(regex("^[a-z]+-[a-z0-9]+[0-9]$", var.region))
    error_message = "region must match a valid GCP region format, e.g., us-central1."
  }
}

variable "service_name" {
  description = "Cloud Run service name"
  type        = string
  default     = "weather-api"
}

variable "repo_id" {
  description = "Artifact Registry repository ID"
  type        = string
  default     = "weather-api"
}

variable "image_tag" {
  description = "Container image tag to deploy"
  type        = string
  validation {
    condition     = length(var.image_tag) > 0 && var.image_tag != "latest"
    error_message = "image_tag must be a non-empty tag and not 'latest'."
  }
}

variable "impersonate_service_account" {
  description = "Optional Email of SA to impersonate (e.g., weather-api-deployer@PROJECT.iam.gserviceaccount.com)"
  type        = string
  default     = ""
}

variable "allow_unauthenticated" {
  description = "Whether to allow public (unauthenticated) invoke"
  type        = bool
  default     = true
}

variable "github_repository" {
  description = "GitHub repo in format owner/repo"
  type        = string
  default     = ""
}

variable "manage_deployer_sa" {
  description = "Whether to create the deployer service account in this stack"
  type        = bool
  default     = false
}
