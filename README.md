# terraform-gcp-IaC

Terraform foundations for a small ecommerce application on Google Cloud.

## Layout

- `main_modules/` defines three shared Cloud Storage buckets and five service accounts with bucket-level IAM.
- `network_database/` defines the shared custom VPC, regional subnets, web ingress firewall, Private Services Access, and private Cloud SQL MySQL instance.
- `shared/` is the sole owner of shared storage, network, and database resources.
- `dev/` and `prod/` are independent Terraform roots with separate remote-state prefixes.

The network and database are created once from `shared/`; `dev/` and `prod/` do not create duplicate VPC or Cloud SQL infrastructure. The shared VPC has a `10.10.0.0/24` public-intended subnet and a `10.10.1.0/24` private-intended subnet in the configured region. GCP subnets are not intrinsically public: a future VM needs an external IP for direct internet ingress, and the web firewall rule only allows TCP 80/443 from the internet to VMs tagged `ecommerce-web`. Cloud SQL has only a private IP through Private Services Access using `10.20.0.0/16`; no public MySQL endpoint or port 3306 ingress rule is created. Check all three ranges against existing project networks before applying.

Cloud SQL is a single-zone MySQL 8.0 instance with automated backups, binary logging, and Terraform deletion protection. Its tier is configurable with `sql_tier`; review the selected tier's ongoing cost before applying. The `ecommerce_dev` and `ecommerce_prod` databases have separate same-named users. Provide `dev_database_password` and `prod_database_password` through a secure Terraform variable source, not source control. Terraform state contains these passwords, so restrict access to the shared state bucket. Cloud NAT is intentionally deferred until private workloads need outbound internet access.

The buckets use uniform bucket-level access, public access prevention, object versioning, and `force_destroy = false`. Bucket names must be globally unique. The service accounts are GCP workload identities, not human Google accounts; use authorized service-account impersonation when a person needs to act as one.

The access mapping is Ibrahim (Storage Admin), Ron and Sandip (Storage Object Viewer), and Klaudio and Teyfik (Storage Object User). These grants apply to all three buckets. Because the app-logs bucket also stores Terraform state, the grants also permit access to state objects according to each role. State can contain sensitive values; this shared access is an explicit security tradeoff.

## Configure and bootstrap

Authenticate the Terraform operator with Application Default Credentials or an approved impersonation flow. The operator also needs permission to create buckets and service accounts, manage bucket IAM, and use the GCS backend. Do not create service-account keys for these identities as part of this configuration.

Create `shared/terraform.tfvars` locally (tfvars files are git-ignored) with the project, bucket location, and three globally unique bucket names:

```hcl
project_id = "your-gcp-project-id"
location   = "us-central1"
region     = "us-central1"
sql_tier   = "db-custom-1-3840"

bucket_names = {
	product_images = "your-unique-product-images-bucket"
	app_logs       = "your-unique-app-logs-bucket"
	backups        = "your-unique-backups-bucket"
}
```

Supply `dev_database_password` and `prod_database_password` securely (for example, through the `TF_VAR_dev_database_password` and `TF_VAR_prod_database_password` environment variables in the Terraform operator's session). Do not put real passwords in this README or commit them in a tfvars file.

Create the buckets using local state first, then migrate that state into the app-logs bucket. Replace the backend bucket value with the configured app-logs name:

```powershell
terraform -chdir=shared init -backend=false
terraform -chdir=shared apply -var-file=terraform.tfvars
terraform -chdir=shared init -migrate-state -backend-config="bucket=your-unique-app-logs-bucket" -backend-config="prefix=terraform/shared"
```

Initialize the environment roots against the same state bucket, each with its own prefix. Supply local `dev/terraform.tfvars` and `prod/terraform.tfvars` containing `project_id` and `region`:

```powershell
terraform -chdir=dev init -backend-config="bucket=your-unique-app-logs-bucket" -backend-config="prefix=terraform/dev"
terraform -chdir=prod init -backend-config="bucket=your-unique-app-logs-bucket" -backend-config="prefix=terraform/prod"
```

The dev and prod roots currently define provider/backend separation only; retain their separate `terraform/dev` and `terraform/prod` state prefixes and do not instantiate the shared module from either root. For a future Flask VM, choose the shared VPC and appropriate subnet, use the `ecommerce-web` network tag only if HTTP/HTTPS ingress is needed, and connect to the Cloud SQL private IP from within the VPC using the environment-specific database/user. The Flask app currently expects AWS SSM credentials and a hard-coded endpoint; migrating it to Cloud SQL and GCP secret/identity services remains a separate follow-up. No VM or Cloud NAT is created here.
