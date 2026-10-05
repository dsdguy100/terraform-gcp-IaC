# terraform-gcp-IaC

Terraform foundations for a small ecommerce application on Google Cloud.

## Layout

- `main_modules/` defines three shared Cloud Storage buckets. The shared root grants project hierarchy-browsing access directly to two configured Google users.
- `network_database/` defines the shared custom VPC, regional subnets, load-balancer ingress firewall, Cloud NAT for the private subnet, Private Services Access, and private Cloud SQL MySQL instance.
- `shared/` is the sole owner of shared storage, network, and database resources.
- `dev/` and `prod/` are independent Terraform roots with separate remote-state prefixes.

The network and database are created once from `shared/`; `dev/` and `prod/` do not create duplicate VPC or Cloud SQL infrastructure. The shared VPC has a `10.10.0.0/24` public-intended subnet and a `10.10.1.0/24` private-intended subnet in the configured region. GCP subnets are not intrinsically public: dev app instances have no external IP and run in the private subnet behind a global HTTP load balancer. The web firewall allows TCP 80 only from Google load-balancer and health-check ranges to VMs tagged `ecommerce-web`; Cloud NAT provides those private instances outbound access. Cloud SQL has only a private IP through Private Services Access using `10.20.0.0/16`; no public MySQL endpoint or port 3306 ingress rule is created. Check all three ranges against existing project networks before applying.

Cloud SQL is a single-zone MySQL 8.0 instance with automated backups, binary logging, and Terraform deletion protection. Its tier is configurable with `sql_tier`; review the selected tier's ongoing cost before applying. The `ecommerce_dev` and `ecommerce_prod` databases have separate same-named users. Provide `dev_database_password` and `prod_database_password` through a secure Terraform variable source, not source control. Terraform state contains these passwords, so restrict access to the `app-log-bucket` used for both application logs and Terraform state. Cloud NAT is scoped to the private subnet and is required for dev instances to install packages and pull the application image; it, the load balancer, and the minimum MIG instance have ongoing costs.

The application buckets use uniform bucket-level access, public access prevention, object versioning, and `force_destroy = false`. Bucket names must be globally unique. The shared root grants Klaudio's configured Google user account the predefined `roles/browser` role on the project, which permits browsing the resource hierarchy but does not grant access to project resources, application bucket objects, Artifact Registry, or Terraform state objects. A project-level custom role cannot include the folder and organization permissions required for hierarchy browsing. This root no longer grants IAM access to developers or Terraform state operators; arrange those permissions separately if needed. Normal ecommerce users authenticate through the app, not GCP IAM. The dev/prod VM service accounts remain workload identities.

Terraform state uses the existing, versioned `app-log-bucket` under separate object prefixes for `shared`, `dev`, and `prod`. The bucket is also used for application logs; its IAM permissions apply at the bucket level unless separately restricted with IAM conditions. State includes database passwords, secret versions, and the dev Flask session secret, so any principal with access to Terraform state objects can read sensitive state. Grant access to this bucket only to trusted operators and review any identities that can access application logs as well. This Terraform root does not manage bucket IAM; the Terraform operator must already have access to the GCS backend. Audit inherited project/organization IAM too.

## Configure and bootstrap

Authenticate the Terraform operator with Application Default Credentials or an approved impersonation flow. The operator also needs permission to manage the project resources and IAM bindings in this root, plus separately granted access to the GCS backend. Do not create service-account keys for these identities as part of this configuration.

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

cloud_readonly_user_email = "klaudio-google-account@example.com"
```

Replace the example address with Klaudio's actual Google account email. Keep these settings and other environment-specific values in the ignored local `shared/terraform.tfvars`; do not create Terraform-managed Google identities or commit personal email addresses.

Supply `dev_database_password` and `prod_database_password` securely (for example, through the `TF_VAR_dev_database_password` and `TF_VAR_prod_database_password` environment variables in the Terraform operator's session). Do not put real passwords in this README or commit them in a tfvars file.

The configured GCS backend uses the existing `app-log-bucket`. For a fresh deployment where the bucket does not yet exist, bootstrap the shared root with local state, then migrate that state to `app-log-bucket`. Local state contains secrets, so protect it and do not commit it:

```powershell
terraform -chdir=shared init -backend=false
terraform -chdir=shared apply -var-file=terraform.tfvars
terraform -chdir=shared init -migrate-state -backend-config="bucket=app-log-bucket" -backend-config="prefix=terraform/shared"
```

This workspace is already initialized with `app-log-bucket` and the prefixes `terraform/shared`, `terraform/dev`, and `terraform/prod`. For this existing deployment, keep using those backend settings and apply the shared changes. Terraform will remove the previous developer, cloud-readonly, and state-operator group bindings it manages; ensure the operator has backend access through the bucket's existing IAM before applying:

```powershell
terraform -chdir=shared apply
```

Initialize dev and prod against the same bucket with their separate prefixes. Set `shared_state_bucket = "app-log-bucket"` in both ignored tfvars files:

```powershell
terraform -chdir=dev init -backend-config="bucket=app-log-bucket" -backend-config="prefix=terraform/dev"
terraform -chdir=prod init -backend-config="bucket=app-log-bucket" -backend-config="prefix=terraform/prod"
```

Verify each root reads its expected state before changing backend configuration. Dev also needs the pushed image URI as described below:

```powershell
terraform -chdir=dev init -backend-config="bucket=app-log-bucket" -backend-config="prefix=terraform/dev"
terraform -chdir=prod init -backend-config="bucket=app-log-bucket" -backend-config="prefix=terraform/prod"
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

### Build and publish the Docker image

Run these commands from the `terraform-gcp-IaC/` directory after the shared apply has created the `ecommerce-app` repository. Docker Desktop (or another Docker Engine) must be running. The active `gcloud` identity needs `roles/artifactregistry.writer` on the repository. Use a new tag for each build so the MIG can roll out a changed image:

```powershell
$project = "fdm-tf-proj"
$region = "us-central1"
$repository = "ecommerce-app"
$tag = Get-Date -Format "yyyyMMdd-HHmmss"
$image = "${region}-docker.pkg.dev/$project/$repository/flask-web:$tag"

gcloud auth configure-docker us-central1-docker.pkg.dev
docker build --pull --tag $image --file .\app_python_mysql-main\Dockerfile .\app_python_mysql-main
docker push $image

gcloud artifacts docker images list us-central1-docker.pkg.dev/fdm-tf-proj/ecommerce-app --include-tags
```

Confirm the image list includes `flask-web` with the new tag. Put that exact `$image` value in the ignored `dev/terraform.tfvars` as `app_image`; also set `project_id`, `region`, and `shared_state_bucket`. For example:

```hcl
project_id          = "fdm-tf-proj"
region              = "us-central1"
shared_state_bucket = "app-log-bucket"
app_image           = "us-central1-docker.pkg.dev/fdm-tf-proj/ecommerce-app/flask-web:replace-with-the-tag-you-built"
```

The old `zone` value is optional and ignored by the regional MIG. `shared_state_prefix` defaults to `terraform/shared`. Supply `flask_session_secret` through a secure variable source, then initialize dev with its existing separate prefix, review the plan, and apply:

```powershell
terraform -chdir=dev init -backend-config="bucket=app-log-bucket" -backend-config="prefix=terraform/dev"
terraform -chdir=dev plan
terraform -chdir=dev apply
```

For a later app release, build and push a new unique tag, update only the `app_image` value in `dev/terraform.tfvars`, then run `terraform -chdir=dev plan` and `terraform -chdir=dev apply`. Terraform updates the instance template/MIG to use the new artifact; wait for the new instance to pass its health check before considering the rollout complete.

The dev root reads outputs from the shared GCS state; it does not create a second VPC or SQL instance. After startup and load-balancer provisioning, run `terraform -chdir=dev output load_balancer_url` and open the returned URL. The reserved global address is also available as `load_balancer_ip`. Use disposable credentials only. Inspect startup output in the Compute Engine serial port logs; the instance startup script installs Docker and Google Cloud CLI, configures Artifact Registry authentication, and starts the tagged image. New instances may take several minutes to become healthy while packages are installed and the app connects to Cloud SQL. SSH is not opened by this configuration. Rebuild and push a new image tag before changing `app_image`.

Terraform state contains the SQL password and Secret Manager secret versions, and dev state contains the Flask session secret. Restrict access to `app-log-bucket` and verify every root reads its expected state. The dev apply replaces the former standalone VM and its ephemeral external IP; the load-balancer address is the new endpoint. The MIG keeps at least one instance running, and the load balancer and shared Cloud NAT also incur costs. Destroy dev resources when they are no longer needed; Cloud SQL and shared networking remain owned by `shared/`, are billable, and Cloud SQL has deletion protection enabled. Production compute, HTTPS, and a CI pipeline are not configured.
