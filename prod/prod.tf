terraform {
  required_version = ">= 1.3.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }

  backend "gcs" {}
}

provider "google" {
  project = var.project_id
  region  = var.region
}

data "terraform_remote_state" "shared" {
  backend = "gcs"

  config = {
    bucket = var.shared_state_bucket
    prefix = var.shared_state_prefix
  }
}

resource "google_service_account" "app_vm" {
  project      = var.project_id
  account_id   = "ecommerce-prod-vm"
  display_name = "Ecommerce production app VM"
}

resource "google_artifact_registry_repository_iam_member" "app_image_reader" {
  project    = var.project_id
  location   = var.region
  repository = data.terraform_remote_state.shared.outputs.artifact_registry_repository_id
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.app_vm.email}"
}

resource "google_secret_manager_secret" "flask_session" {
  project   = var.project_id
  secret_id = "ecommerce-prod-flask-session"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "flask_session" {
  secret      = google_secret_manager_secret.flask_session.id
  secret_data = var.flask_session_secret
}

resource "google_secret_manager_secret_iam_member" "database_password_reader" {
  project   = var.project_id
  secret_id = data.terraform_remote_state.shared.outputs.prod_database_password_secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.app_vm.email}"
}

resource "google_secret_manager_secret_iam_member" "flask_session_reader" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.flask_session.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.app_vm.email}"
}

resource "google_compute_instance" "app_vm" {
  project                   = var.project_id
  name                      = "ecommerce-prod-app"
  zone                      = var.zone
  machine_type              = var.machine_type
  allow_stopping_for_update = true

  boot_disk {
    initialize_params {
      image = "projects/debian-cloud/global/images/family/debian-12"
      size  = var.boot_disk_size_gb
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = data.terraform_remote_state.shared.outputs.subnets.public.self_link

    access_config {}
  }

  service_account {
    email  = google_service_account.app_vm.email
    scopes = ["cloud-platform"]
  }

  tags = ["ecommerce-prod-web"]

  metadata_startup_script = templatefile("${path.module}/../dev/startup.sh.tftpl", {
    app_image                = var.app_image
    database_host            = data.terraform_remote_state.shared.outputs.database_connection.private_ip
    database_name            = "ecommerce_prod"
    database_password_secret = data.terraform_remote_state.shared.outputs.prod_database_password_secret_id
    database_user            = "ecommerce_prod"
    flask_session_secret     = google_secret_manager_secret.flask_session.secret_id
    project_id               = var.project_id
    registry_host            = "${var.region}-docker.pkg.dev"
  })

  depends_on = [
    google_artifact_registry_repository_iam_member.app_image_reader,
    google_secret_manager_secret_iam_member.database_password_reader,
    google_secret_manager_secret_iam_member.flask_session_reader,
  ]
}

output "app_vm_external_ip" {
  description = "External HTTP address for the production Flask VM."
  value       = google_compute_instance.app_vm.network_interface[0].access_config[0].nat_ip
}

output "app_vm_internal_ip" {
  description = "Internal address of the production Flask VM."
  value       = google_compute_instance.app_vm.network_interface[0].network_ip
}

output "app_url" {
  description = "HTTP URL for the production Flask application."
  value       = "http://${google_compute_instance.app_vm.network_interface[0].access_config[0].nat_ip}"
}
