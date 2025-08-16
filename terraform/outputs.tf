output "cloud_run_uri" {
  description = "The HTTPS endpoint of the deployed Cloud Run service"
  value       = google_cloud_run_v2_service.service.uri
}

output "image_url" {
  description = "The Artifact Registry Docker image URL deployed to Cloud Run"
  value       = local.image_url
}
