variable "project_id" {
  description = "Google Cloud project ID for development resources."
  type        = string
}

variable "region" {
  description = "Default Google Cloud region for development resources."
  type        = string
}

variable "zone" {
  description = "Legacy single-VM zone setting; the regional MIG selects available zones in region."
  type        = string
  default     = null
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
  description = "Compute Engine machine type for each dev managed instance group member."
  type        = string
  default     = "e2-small"
}

variable "boot_disk_size_gb" {
  description = "Boot disk size for each dev managed instance group member."
  type        = number
  default     = 20
}

variable "min_replicas" {
  description = "Minimum number of dev application instances in the regional managed instance group."
  type        = number
  default     = 1

  validation {
    condition     = var.min_replicas >= 1 && floor(var.min_replicas) == var.min_replicas
    error_message = "min_replicas must be a whole number of at least 1."
  }
}

variable "max_replicas" {
  description = "Maximum number of dev application instances in the regional managed instance group."
  type        = number
  default     = 3

  validation {
    condition     = var.max_replicas >= 1 && floor(var.max_replicas) == var.max_replicas
    error_message = "max_replicas must be a whole number of at least 1."
  }
}

variable "cpu_target" {
  description = "Average CPU utilization target for dev managed instance group autoscaling."
  type        = number
  default     = 0.6

  validation {
    condition     = var.cpu_target > 0 && var.cpu_target <= 1
    error_message = "cpu_target must be greater than 0 and at most 1."
  }
}