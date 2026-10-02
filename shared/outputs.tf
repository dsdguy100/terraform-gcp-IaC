output "bucket_names" {
  description = "Names of the shared application storage buckets."
  value       = module.shared_storage.bucket_names
}

output "service_account_emails" {
  description = "Email addresses of the storage access service accounts."
  value       = module.shared_storage.service_account_emails
}

output "vpc_name" {
  description = "Name of the shared custom VPC."
  value       = module.network_database.vpc_name
}

output "vpc_self_link" {
  description = "Self link of the shared custom VPC."
  value       = module.network_database.vpc_self_link
}

output "subnets" {
  description = "Names, self links, and CIDR ranges of the regional shared subnets."
  value       = module.network_database.subnets
}

output "database_connection" {
  description = "Private Cloud SQL connection details and logical database/user names."
  value       = module.network_database.database_connection
}