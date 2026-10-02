locals {
  bucket_names = {
    product_images = var.bucket_names.product_images
    app_logs       = var.bucket_names.app_logs
    backups        = var.bucket_names.backups
  }
}

resource "google_storage_bucket" "app" {
  for_each = local.bucket_names

  name                        = each.value
  project                     = var.project_id
  location                    = var.location
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false

  versioning {
    enabled = true
  }
}
