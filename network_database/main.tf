resource "google_compute_network" "shared" {
  project                 = var.project_id
  name                    = var.network_name
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

resource "google_compute_subnetwork" "public" {
  project                  = var.project_id
  name                     = "${var.network_name}-public-${var.region}"
  ip_cidr_range            = var.public_subnet_cidr
  region                   = var.region
  network                  = google_compute_network.shared.id
  private_ip_google_access = true
}

resource "google_compute_subnetwork" "private" {
  project                  = var.project_id
  name                     = "${var.network_name}-private-${var.region}"
  ip_cidr_range            = var.private_subnet_cidr
  region                   = var.region
  network                  = google_compute_network.shared.id
  private_ip_google_access = true
}

resource "google_compute_router" "shared" {
  project = var.project_id
  name    = "${var.network_name}-${var.region}-router"
  region  = var.region
  network = google_compute_network.shared.id
}

resource "google_compute_router_nat" "private" {
  project                            = var.project_id
  name                               = "${var.network_name}-${var.region}-private-nat"
  router                             = google_compute_router.shared.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = google_compute_subnetwork.private.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
}

resource "google_compute_firewall" "web_ingress" {
  project       = var.project_id
  name          = "${var.network_name}-web-ingress"
  network       = google_compute_network.shared.id
  direction     = "INGRESS"
  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
  target_tags   = ["ecommerce-web"]

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }
}

resource "google_compute_global_address" "private_services" {
  project       = var.project_id
  name          = "${var.network_name}-private-services"
  address_type  = "INTERNAL"
  purpose       = "VPC_PEERING"
  address       = cidrhost(var.private_services_cidr, 0)
  prefix_length = tonumber(split("/", var.private_services_cidr)[1])
  network       = google_compute_network.shared.id
}

resource "google_service_networking_connection" "private_services" {
  network                 = google_compute_network.shared.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_services.name]
}

resource "google_sql_database_instance" "mysql" {
  project             = var.project_id
  name                = var.sql_instance_name
  region              = var.region
  database_version    = "MYSQL_8_0"
  deletion_protection = true

  settings {
    tier              = var.sql_tier
    availability_type = "ZONAL"
    disk_type         = "PD_SSD"
    disk_size         = 20
    disk_autoresize   = true

    backup_configuration {
      enabled            = true
      binary_log_enabled = true
      start_time         = "03:00"
    }

    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.shared.id
    }
  }

  depends_on = [google_service_networking_connection.private_services]
}

resource "google_sql_database" "logical" {
  for_each = toset(["ecommerce_dev", "ecommerce_prod"])

  project  = var.project_id
  name     = each.value
  instance = google_sql_database_instance.mysql.name
}

resource "google_sql_user" "logical" {
  for_each = {
    ecommerce_dev  = var.dev_database_password
    ecommerce_prod = var.prod_database_password
  }

  project  = var.project_id
  name     = each.key
  instance = google_sql_database_instance.mysql.name
  password = each.value
}