variable "project_id" {
  description = "Google Cloud project that owns the shared resources."
  type        = string
}

variable "region" {
  description = "Google Cloud region for the shared VPC subnets and Cloud SQL instance."
  type        = string
}

variable "location" {
  description = "Cloud Storage bucket location, such as US or us-central1."
  type        = string
}

variable "bucket_names" {
  description = "Globally unique names for the application storage buckets."
  type = object({
    product_images = string
    app_logs       = string
    backups        = string
  })

  validation {
    condition     = length(distinct(values(var.bucket_names))) == 3
    error_message = "Each application bucket must have a different name."
  }
}

variable "network_name" {
  description = "Name of the shared custom VPC."
  type        = string
  default     = "ecommerce-shared"
}

variable "sql_instance_name" {
  description = "Name of the shared private Cloud SQL instance."
  type        = string
  default     = "ecommerce-mysql"
}

variable "sql_tier" {
  description = "Cloud SQL machine tier; review its ongoing cost before applying."
  type        = string
  default     = "db-custom-1-3840"
}

variable "artifact_registry_repository" {
  description = "Artifact Registry Docker repository for application images."
  type        = string
  default     = "ecommerce-app"
}

variable "dev_database_password" {
  description = "Password for the ecommerce_dev database user. Supply through a secure variable source."
  type        = string
  sensitive   = true
}

variable "prod_database_password" {
  description = "Password for the ecommerce_prod database user. Supply through a secure variable source."
  type        = string
  sensitive   = true
}