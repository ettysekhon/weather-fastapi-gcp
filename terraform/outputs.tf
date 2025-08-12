output "cloud_run_uri" {
  value = google_cloud_run_v2_service.service.uri
}

output "image_url" {
  value = local.image_url
}
