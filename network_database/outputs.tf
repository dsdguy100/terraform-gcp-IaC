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
      name       = google_compute_subnetwork.public.name
      self_link  = google_compute_subnetwork.public.self_link
      cidr_range = google_compute_subnetwork.public.ip_cidr_range
    }
    private = {
      name       = google_compute_subnetwork.private.name
      self_link  = google_compute_subnetwork.private.self_link
      cidr_range = google_compute_subnetwork.private.ip_cidr_range
    }
  }
}

output "database_connection" {
  description = "Private-only connection details and logical database/user names."
  value = {
    instance_name   = google_sql_database_instance.mysql.name
    connection_name = google_sql_database_instance.mysql.connection_name
    private_ip      = one(google_sql_database_instance.mysql.ip_address[*].ip_address)
    databases       = [for database in google_sql_database.logical : database.name]
    users           = [for user in google_sql_user.logical : user.name]
    public_ip       = null
  }
}