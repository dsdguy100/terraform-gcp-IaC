output "bucket_names" {
  description = "Names of the shared application storage buckets."
  value       = module.shared_storage.bucket_names
}

output "service_account_emails" {
  description = "Email addresses of the storage access service accounts."
  value       = module.shared_storage.service_account_emails
}

output "storage_buckets" {
  description = "Configuration and identifiers for all managed Cloud Storage buckets."
  value       = module.shared_storage.storage_buckets
}

output "storage_service_accounts" {
  description = "Identity metadata for all managed storage service accounts."
  value       = module.shared_storage.storage_service_accounts
}

output "storage_bucket_iam" {
  description = "Explicit service-account IAM grants on managed Cloud Storage buckets."
  value       = module.shared_storage.storage_bucket_iam
}

output "vpc_name" {
  description = "Name of the shared custom VPC."
  value       = module.network_database.vpc_name
}

output "vpc_self_link" {
  description = "Self link of the shared custom VPC."
  value       = module.network_database.vpc_self_link
}

output "subnets" {
  description = "Names, self links, and CIDR ranges of the regional shared subnets."
  value       = module.network_database.subnets
}

output "cloud_router" {
  description = "Cloud Router metadata for the shared VPC."
  value       = module.network_database.cloud_router
}

output "cloud_nat" {
  description = "Cloud NAT configuration for private subnet egress."
  value       = module.network_database.cloud_nat
}

output "firewall_rules" {
  description = "Configured VPC firewall rules managed by the shared root."
  value       = module.network_database.firewall_rules
}

output "private_services_access" {
  description = "Private Services Access allocation and peering metadata."
  value       = module.network_database.private_services_access
}

output "database_connection" {
  description = "Private Cloud SQL connection details and logical database/user names."
  value       = module.network_database.database_connection
}

output "artifact_registry_repository_id" {
  description = "Fully qualified Artifact Registry repository ID."
  value       = google_artifact_registry_repository.app.id
}

output "artifact_registry_repository_url" {
  description = "Docker image base URL for the shared Artifact Registry repository."
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.app.repository_id}"
}

output "artifact_registry" {
  description = "Artifact Registry repository metadata."
  value = {
    id            = google_artifact_registry_repository.app.id
    repository_id = google_artifact_registry_repository.app.repository_id
    project       = google_artifact_registry_repository.app.project
    location      = google_artifact_registry_repository.app.location
    format        = google_artifact_registry_repository.app.format
    url           = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.app.repository_id}"
  }
}

output "enabled_services" {
  description = "Google Cloud APIs enabled by the shared root."
  value       = sort([for service in google_project_service.required : service.service])
}

output "dev_database_password_secret_id" {
  description = "Secret Manager resource ID for the dev database password."
  value       = google_secret_manager_secret.dev_database_password.id
}