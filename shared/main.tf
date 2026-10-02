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
    "artifactregistry.googleapis.com",
    "secretmanager.googleapis.com",
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

resource "google_storage_bucket" "terraform_state" {
  project                     = var.project_id
  name                        = var.terraform_state_bucket_name
  location                    = var.location
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false

  versioning {
    enabled = true
  }

  lifecycle {
    prevent_destroy = true

    precondition {
      condition     = !contains(values(var.bucket_names), var.terraform_state_bucket_name)
      error_message = "The Terraform state bucket must have a unique name separate from the application buckets."
    }
  }
}

resource "google_storage_bucket_iam_member" "terraform_state_operators" {
  bucket = google_storage_bucket.terraform_state.name
  role   = "roles/storage.objectAdmin"
  member = "group:${var.terraform_state_operator_group_email}"
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

resource "google_artifact_registry_repository" "app" {
  project       = var.project_id
  location      = var.region
  repository_id = var.artifact_registry_repository
  format        = "DOCKER"

  depends_on = [google_project_service.required]
}

resource "google_artifact_registry_repository_iam_member" "developers" {
  project    = var.project_id
  location   = var.region
  repository = google_artifact_registry_repository.app.repository_id
  role       = "roles/artifactregistry.writer"
  member     = "group:${var.developer_group_email}"
}

resource "google_project_iam_member" "cloud_readonly" {
  project = var.project_id
  role    = "roles/browser"
  member  = "group:${var.cloud_readonly_group_email}"
}

resource "google_secret_manager_secret" "dev_database_password" {
  project   = var.project_id
  secret_id = "ecommerce-dev-db-password"

  replication {
    auto {}
  }

  depends_on = [google_project_service.required]
}

resource "google_secret_manager_secret_version" "dev_database_password" {
  secret      = google_secret_manager_secret.dev_database_password.id
  secret_data = var.dev_database_password
}

resource "google_secret_manager_secret" "prod_database_password" {
  project   = var.project_id
  secret_id = "ecommerce-prod-db-password"

  replication {
    auto {}
  }

  depends_on = [google_project_service.required]
}

resource "google_secret_manager_secret_version" "prod_database_password" {
  secret      = google_secret_manager_secret.prod_database_password.id
  secret_data = var.prod_database_password
}
