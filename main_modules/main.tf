locals {
  bucket_names = {
    product_images = var.bucket_names.product_images
    app_logs       = var.bucket_names.app_logs
    backups        = var.bucket_names.backups
  }

  users = {
    ibrahim = {
      display_name = "Ibrahim"
      role         = "roles/storage.admin"
    }
    ron = {
      display_name = "Ron"
      role         = "roles/storage.objectViewer"
    }
    sandip = {
      display_name = "Sandip"
      role         = "roles/storage.objectViewer"
    }
    klaudio = {
      display_name = "Klaudio"
      role         = "roles/storage.objectUser"
    }
    teyfik = {
      display_name = "Teyfik"
      role         = "roles/storage.objectUser"
    }
  }

  bucket_access = {
    for binding in setproduct(keys(local.bucket_names), keys(local.users)) :
    "${binding[0]}-${binding[1]}" => {
      bucket_key = binding[0]
      user_key   = binding[1]
    }
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

resource "google_service_account" "user" {
  for_each = local.users

  project      = var.project_id
  account_id   = each.key
  display_name = each.value.display_name
  description  = "Storage access identity for ${each.value.display_name}"
}

resource "google_storage_bucket_iam_member" "user_access" {
  for_each = local.bucket_access

  bucket = google_storage_bucket.app[each.value.bucket_key].name
  role   = local.users[each.value.user_key].role
  member = "serviceAccount:${google_service_account.user[each.value.user_key].email}"
}
