variable "project_id" {
  description = "Google Cloud project that owns the buckets and service accounts."
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