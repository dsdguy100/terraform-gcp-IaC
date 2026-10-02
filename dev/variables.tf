variable "project_id" {
  description = "Google Cloud project ID for development resources."
  type        = string
}

variable "region" {
  description = "Default Google Cloud region for development resources."
  type        = string
}

variable "zone" {
  description = "Compute Engine zone for the development application VM."
  type        = string
}

variable "shared_state_bucket" {
  description = "GCS bucket containing the shared Terraform state."
  type        = string
}

variable "shared_state_prefix" {
  description = "GCS prefix for the shared Terraform state."
  type        = string
  default     = "terraform/shared"
}

variable "app_image" {
  description = "Fully qualified, tagged Artifact Registry image URI to run on the dev VM."
  type        = string
}

variable "flask_session_secret" {
  description = "Secret key used to sign Flask sessions. Supply through a secure variable source."
  type        = string
  sensitive   = true
}

variable "machine_type" {
  description = "Compute Engine machine type for the dev application VM."
  type        = string
  default     = "e2-small"
}

variable "boot_disk_size_gb" {
  description = "Boot disk size for the dev application VM."
  type        = number
  default     = 20
}