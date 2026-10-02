output "vpc_name" {
  description = "Name of the custom VPC."
  value       = google_compute_network.shared.name
}

output "vpc_self_link" {
  description = "Self link of the custom VPC."
  value       = google_compute_network.shared.self_link
}

output "subnets" {
  description = "Regional subnet names, self links, and CIDR ranges."
  value = {
    public = {
      name                     = google_compute_subnetwork.public.name
      self_link                = google_compute_subnetwork.public.self_link
      cidr_range               = google_compute_subnetwork.public.ip_cidr_range
      region                   = google_compute_subnetwork.public.region
      private_ip_google_access = google_compute_subnetwork.public.private_ip_google_access
    }
    private = {
      name                     = google_compute_subnetwork.private.name
      self_link                = google_compute_subnetwork.private.self_link
      cidr_range               = google_compute_subnetwork.private.ip_cidr_range
      region                   = google_compute_subnetwork.private.region
      private_ip_google_access = google_compute_subnetwork.private.private_ip_google_access
    }
  }
}

output "cloud_router" {
  description = "Cloud Router metadata for the shared VPC."
  value = {
    name    = google_compute_router.shared.name
    region  = google_compute_router.shared.region
    network = google_compute_router.shared.network
    id      = google_compute_router.shared.id
  }
}

output "cloud_nat" {
  description = "Cloud NAT configuration for private subnet egress."
  value = {
    name                               = google_compute_router_nat.private.name
    router                             = google_compute_router_nat.private.router
    region                             = google_compute_router_nat.private.region
    nat_ip_allocate_option             = google_compute_router_nat.private.nat_ip_allocate_option
    source_subnetwork_ip_ranges_to_nat = google_compute_router_nat.private.source_subnetwork_ip_ranges_to_nat
    subnetworks = [
      for subnet in google_compute_router_nat.private.subnetwork : {
        name                    = subnet.name
        source_ip_ranges_to_nat = subnet.source_ip_ranges_to_nat
      }
    ]
  }
}

output "firewall_rules" {
  description = "Ingress firewall rule configuration for web instances."
  value = {
    web_ingress = {
      name          = google_compute_firewall.web_ingress.name
      id            = google_compute_firewall.web_ingress.id
      direction     = google_compute_firewall.web_ingress.direction
      network       = google_compute_firewall.web_ingress.network
      source_ranges = google_compute_firewall.web_ingress.source_ranges
      target_tags   = google_compute_firewall.web_ingress.target_tags
      allowed = [
        for rule in google_compute_firewall.web_ingress.allow : {
          protocol = rule.protocol
          ports    = rule.ports
        }
      ]
    }
  }
}

output "private_services_access" {
  description = "Private Services Access allocation and peering metadata for Cloud SQL."
  value = {
    reserved_range_name = google_compute_global_address.private_services.name
    reserved_range_cidr = var.private_services_cidr
    network             = google_compute_network.shared.self_link
    service             = google_service_networking_connection.private_services.service
    peering             = google_service_networking_connection.private_services.peering
  }
}

output "database_connection" {
  description = "Cloud SQL instance metadata and private connection details; excludes credentials."
  value = {
    instance_name     = google_sql_database_instance.mysql.name
    connection_name   = google_sql_database_instance.mysql.connection_name
    region            = google_sql_database_instance.mysql.region
    database_version  = google_sql_database_instance.mysql.database_version
    tier              = google_sql_database_instance.mysql.settings[0].tier
    availability_type = google_sql_database_instance.mysql.settings[0].availability_type
    private_ip        = one(google_sql_database_instance.mysql.ip_address[*].ip_address)
    databases         = [for database in google_sql_database.logical : database.name]
    users             = [for user in google_sql_user.logical : user.name]
    public_ip         = null
  }
}