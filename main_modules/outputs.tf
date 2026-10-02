output "bucket_names" {
  description = "Names of the shared application storage buckets."
  value       = { for key, bucket in google_storage_bucket.app : key => bucket.name }
}

output "service_account_emails" {
  description = "Email addresses of the storage access service accounts."
  value       = { for key, account in google_service_account.user : key => account.email }
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

output "storage_service_accounts" {
  description = "Identity metadata for all managed storage service accounts."
  value = {
    for key, account in google_service_account.user : key => {
      account_id   = account.account_id
      display_name = account.display_name
      email        = account.email
      unique_id    = account.unique_id
    }
  }
}

output "storage_bucket_iam" {
  description = "Explicit service-account IAM grants on managed Cloud Storage buckets."
  value = {
    for key, grant in google_storage_bucket_iam_member.user_access : key => {
      id     = grant.id
      bucket = grant.bucket
      member = grant.member
      role   = grant.role
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