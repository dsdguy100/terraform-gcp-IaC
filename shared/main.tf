provider "google" {
  project = var.project_id
}

resource "google_project_service" "required" {
  for_each = toset([
    "storage.googleapis.com",
    "iam.googleapis.com",
    "compute.googleapis.com",
    "sqladmin.googleapis.com",
    "servicenetworking.googleapis.com",
  ])

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

module "shared_storage" {
  source = "../main_modules"

  project_id   = var.project_id
  location     = var.location
  bucket_names = var.bucket_names

  depends_on = [google_project_service.required]
}

module "network_database" {
  source = "../network_database"

  project_id             = var.project_id
  region                 = var.region
  network_name           = var.network_name
  sql_instance_name      = var.sql_instance_name
  sql_tier               = var.sql_tier
  dev_database_password  = var.dev_database_password
  prod_database_password = var.prod_database_password

  depends_on = [google_project_service.required]
}
