variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
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
  # no default on purpose – force explicit tagging
  # default     = "latest"
  validation {
    condition     = length(var.image_tag) > 0 && var.image_tag != "latest"
    error_message = "image_tag must be a non-empty tag and not 'latest'."
  }
}

variable "impersonate_service_account" {
  description = "Email of SA to impersonate (e.g., weather-api-deployer@PROJECT.iam.gserviceaccount.com)"
  type        = string
}

variable "allow_unauthenticated" {
  description = "Whether to allow public (unauthenticated) invoke"
  type        = bool
  default     = true
}

variable "github_repository" {
  description = "GitHub repo in format owner/repo"
  type        = string
}
