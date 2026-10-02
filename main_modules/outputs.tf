output "bucket_names" {
  description = "Names of the shared application storage buckets."
  value       = { for key, bucket in google_storage_bucket.app : key => bucket.name }
}

output "storage_buckets" {
  description = "Configuration and identifiers for all managed Cloud Storage buckets."
  value = {
    for key, bucket in google_storage_bucket.app : key => {
      name                        = bucket.name
      id                          = bucket.id
      project                     = bucket.project
      location                    = bucket.location
      self_link                   = bucket.self_link
      uniform_bucket_level_access = bucket.uniform_bucket_level_access
      public_access_prevention    = bucket.public_access_prevention
      versioning_enabled          = bucket.versioning[0].enabled
      force_destroy               = bucket.force_destroy
    }
  }
}

# o Endpoint of ALB DNS
# o EC2 instances
# o All S3 buckets name
# o All users name
# o VPC
# o Database endpoint
# o Security Group ID
# o Subnets