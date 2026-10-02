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
  account_id   = "ecommerce-dev-vm"
  display_name = "Ecommerce development app VM"
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
  secret_id = "ecommerce-dev-flask-session"

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
  secret_id = data.terraform_remote_state.shared.outputs.dev_database_password_secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.app_vm.email}"
}

resource "google_secret_manager_secret_iam_member" "flask_session_reader" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.flask_session.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.app_vm.email}"
}

data "google_compute_zones" "available" {
  project = var.project_id
  region  = var.region
  status  = "UP"
}

resource "google_compute_instance_template" "app" {
  project      = var.project_id
  name_prefix  = "ecommerce-dev-app-"
  machine_type = var.machine_type
  tags         = ["ecommerce-web"]

  disk {
    source_image = "projects/debian-cloud/global/images/family/debian-12"
    auto_delete  = true
    boot         = true
    disk_size_gb = var.boot_disk_size_gb
    disk_type    = "pd-balanced"
  }

  network_interface {
    subnetwork = data.terraform_remote_state.shared.outputs.subnets.private.self_link
  }

  service_account {
    email  = google_service_account.app_vm.email
    scopes = ["cloud-platform"]
  }

  metadata_startup_script = templatefile("${path.module}/startup.sh.tftpl", {
    app_image                = var.app_image
    database_host            = data.terraform_remote_state.shared.outputs.database_connection.private_ip
    database_name            = "ecommerce_dev"
    database_password_secret = data.terraform_remote_state.shared.outputs.dev_database_password_secret_id
    database_user            = "ecommerce_dev"
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

resource "google_compute_health_check" "app" {
  project             = var.project_id
  name                = "ecommerce-dev-app-health"
  check_interval_sec  = 5
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 3

  http_health_check {
    port         = 80
    request_path = "/"
  }
}

resource "google_compute_region_instance_group_manager" "app" {
  project                   = var.project_id
  name                      = "ecommerce-dev-app-mig"
  base_instance_name        = "ecommerce-dev-app"
  region                    = var.region
  distribution_policy_zones = data.google_compute_zones.available.names
  target_size               = var.min_replicas

  version {
    name              = "app"
    instance_template = google_compute_instance_template.app.self_link
  }

  named_port {
    name = "http"
    port = 80
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.app.self_link
    initial_delay_sec = 600
  }
}

resource "google_compute_region_autoscaler" "app" {
  project = var.project_id
  name    = "ecommerce-dev-app-autoscaler"
  region  = var.region
  target  = google_compute_region_instance_group_manager.app.id

  lifecycle {
    precondition {
      condition     = var.max_replicas >= var.min_replicas
      error_message = "max_replicas must be greater than or equal to min_replicas."
    }
  }

  autoscaling_policy {
    min_replicas    = var.min_replicas
    max_replicas    = var.max_replicas
    cooldown_period = 300

    cpu_utilization {
      target = var.cpu_target
    }
  }
}

resource "google_compute_backend_service" "app" {
  project               = var.project_id
  name                  = "ecommerce-dev-app-backend"
  protocol              = "HTTP"
  port_name             = "http"
  load_balancing_scheme = "EXTERNAL"
  timeout_sec           = 30
  health_checks         = [google_compute_health_check.app.id]

  backend {
    group           = google_compute_region_instance_group_manager.app.instance_group
    balancing_mode  = "UTILIZATION"
    max_utilization = 0.8
  }
}

resource "google_compute_url_map" "app" {
  project         = var.project_id
  name            = "ecommerce-dev-app-url-map"
  default_service = google_compute_backend_service.app.id
}

resource "google_compute_target_http_proxy" "app" {
  project = var.project_id
  name    = "ecommerce-dev-app-http-proxy"
  url_map = google_compute_url_map.app.id
}

resource "google_compute_global_address" "app" {
  project = var.project_id
  name    = "ecommerce-dev-app-lb-ip"
}

resource "google_compute_global_forwarding_rule" "app" {
  project               = var.project_id
  name                  = "ecommerce-dev-app-http-forwarding-rule"
  ip_address            = google_compute_global_address.app.address
  ip_protocol           = "TCP"
  port_range            = "80"
  target                = google_compute_target_http_proxy.app.id
  load_balancing_scheme = "EXTERNAL"
}

