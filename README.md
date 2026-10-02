# terraform-gcp-IaC

Terraform foundations for a small ecommerce application on Google Cloud.

## Layout

- `main_modules/` defines three shared Cloud Storage buckets and five service accounts with bucket-level IAM.
- `network_database/` defines the shared custom VPC, regional subnets, load-balancer ingress firewall, Cloud NAT for the private subnet, Private Services Access, and private Cloud SQL MySQL instance.
- `shared/` is the sole owner of shared storage, network, and database resources.
- `dev/` and `prod/` are independent Terraform roots with separate remote-state prefixes.

The network and database are created once from `shared/`; `dev/` and `prod/` do not create duplicate VPC or Cloud SQL infrastructure. The shared VPC has a `10.10.0.0/24` public-intended subnet and a `10.10.1.0/24` private-intended subnet in the configured region. GCP subnets are not intrinsically public: dev app instances have no external IP and run in the private subnet behind a global HTTP load balancer. The web firewall allows TCP 80 only from Google load-balancer and health-check ranges to VMs tagged `ecommerce-web`; Cloud NAT provides those private instances outbound access. Cloud SQL has only a private IP through Private Services Access using `10.20.0.0/16`; no public MySQL endpoint or port 3306 ingress rule is created. Check all three ranges against existing project networks before applying.

Cloud SQL is a single-zone MySQL 8.0 instance with automated backups, binary logging, and Terraform deletion protection. Its tier is configurable with `sql_tier`; review the selected tier's ongoing cost before applying. The `ecommerce_dev` and `ecommerce_prod` databases have separate same-named users. Provide `dev_database_password` and `prod_database_password` through a secure Terraform variable source, not source control. Terraform state contains these passwords, so restrict access to the shared state bucket. Cloud NAT is scoped to the private subnet and is required for dev instances to install packages and pull the application image; it, the load balancer, and the minimum MIG instance have ongoing costs.

The buckets use uniform bucket-level access, public access prevention, object versioning, and `force_destroy = false`. Bucket names must be globally unique. The service accounts are GCP workload identities, not human Google accounts; use authorized service-account impersonation when a person needs to act as one.

The access mapping is Ibrahim (Storage Admin), Ron and Sandip (Storage Object Viewer), and Klaudio and Teyfik (Storage Object User). These grants apply to all three buckets. Because the app-logs bucket also stores Terraform state, the grants also permit access to state objects according to each role. State can contain sensitive values; this shared access is an explicit security tradeoff.

## Configure and bootstrap

Authenticate the Terraform operator with Application Default Credentials or an approved impersonation flow. The operator also needs permission to create buckets and service accounts, manage bucket IAM, and use the GCS backend. Do not create service-account keys for these identities as part of this configuration.

Create `shared/terraform.tfvars` locally (tfvars files are git-ignored) with the project, bucket location, and three globally unique bucket names:

```hcl
project_id = "your-gcp-project-id"
location   = "us-central1"
region     = "us-central1"
sql_tier   = "db-f1-micro"

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

Initialize the environment roots against the same state bucket, each with its own prefix. The prod root needs `project_id` and `region`; the dev root also needs its zone, shared-state bucket, and pushed image URI as described below:

```powershell
terraform -chdir=dev init -backend-config="bucket=your-unique-app-logs-bucket" -backend-config="prefix=terraform/dev"
terraform -chdir=prod init -backend-config="bucket=your-unique-app-logs-bucket" -backend-config="prefix=terraform/prod"
```

The dev and prod roots retain separate `terraform/dev` and `terraform/prod` state prefixes. Shared network, SQL, Artifact Registry, and dev database-password secret resources are owned only by `shared/`.

## Deploy the dev Flask app

The dev web deployment is a regional Debian Compute Engine Managed Instance Group (MIG) in the shared VPC's private subnet, behind a public global HTTP load balancer on port 80. The MIG starts with one instance, scales from one to three at a 60% average CPU target, and uses a health check on `/`. Instances have no external IP; Cloud NAT provides outbound package and Artifact Registry access. Each instance uses a dedicated service account to pull the app image and read only the dev database password and Flask session key from Secret Manager. SQL remains private, and neither 3306 nor 5000 is exposed to the internet. This is for disposable test data only, not production; traffic is HTTP-only, so do not use real credentials or data.

The Python app no longer uses AWS SSM or hard-coded database settings. It connects to `ecommerce_dev` and hashes newly submitted passwords. The dev SQL user needs schema permissions because the app creates its tables on startup. After the shared apply creates the Cloud SQL user, connect as an authorized database administrator using Cloud SQL Studio and run:

```sql
GRANT CREATE, REFERENCES, SELECT, INSERT, UPDATE, DELETE
ON ecommerce_dev.* TO 'ecommerce_dev'@'%';
```

Apply shared resources first, supplying the dev/prod SQL passwords through secure Terraform variables. The dev password is also written to the shared Secret Manager secret, so the user password and secret value stay synchronized:

```powershell
terraform -chdir=shared apply
```

Build and push a tagged image after the shared apply creates the Artifact Registry repository. Run these commands from `terraform-gcp-IaC/` and replace the project/repository values as needed:

```powershell
$image = "us-central1-docker.pkg.dev/fdm-tf-proj/ecommerce-app/flask-web:dev-001"
gcloud auth configure-docker us-central1-docker.pkg.dev
docker build -t $image .\app_python_mysql-main
docker push $image
```

Create ignored `dev/terraform.tfvars` with `project_id`, `region`, `shared_state_bucket`, and the tagged `app_image`. The old `zone` value is optional and ignored by the regional MIG. Set `shared_state_bucket` to the same bucket used by the shared/dev backends; `shared_state_prefix` defaults to `terraform/shared`. Supply `flask_session_secret` through a secure variable source, then initialize dev with its existing separate prefix and apply:

```powershell
terraform -chdir=dev init -backend-config="bucket=your-unique-app-logs-bucket" -backend-config="prefix=terraform/dev"
terraform -chdir=dev plan
terraform -chdir=dev apply
```

The dev root reads outputs from the shared GCS state; it does not create a second VPC or SQL instance. After startup and load-balancer provisioning, run `terraform -chdir=dev output load_balancer_url` and open the returned URL. The reserved global address is also available as `load_balancer_ip`. Use disposable credentials only. Inspect startup output in the Compute Engine serial port logs; the instance startup script installs Docker and Google Cloud CLI, configures Artifact Registry authentication, and starts the tagged image. New instances may take several minutes to become healthy while packages are installed and the app connects to Cloud SQL. SSH is not opened by this configuration. Rebuild and push a new image tag before changing `app_image`.

Terraform state contains the SQL password and the Secret Manager secret versions, so restrict access to both shared and dev state. The current dev session secret is also stored in dev state. The dev apply replaces the former standalone VM and its ephemeral external IP; the load-balancer address is the new endpoint. The MIG keeps at least one instance running, and the load balancer and shared Cloud NAT also incur costs. Destroy dev resources when they are no longer needed; Cloud SQL and shared networking remain owned by `shared/`, are billable, and Cloud SQL has deletion protection enabled. Production compute, HTTPS, and a CI pipeline are not configured.
