output "bucket_names" {
  description = "Names of the shared application storage buckets."
  value       = { for key, bucket in google_storage_bucket.app : key => bucket.name }
}

output "service_account_emails" {
  description = "Email addresses of the storage access service accounts."
  value       = { for key, account in google_service_account.user : key => account.email }
}
# o Endpoint of ALB DNS
# o EC2 instances
# o All S3 buckets name
# o All users name
# o VPC
# o Database endpoint
# o Security Group ID
# o Subnets