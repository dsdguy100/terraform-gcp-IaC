variable "project_id" {
  description = "Google Cloud project that owns the network and database."
  type        = string
}

variable "region" {
  description = "Region for the subnets and single-zone Cloud SQL instance."
  type        = string
}

variable "network_name" {
  description = "Name of the custom VPC."
  type        = string
}

variable "public_subnet_cidr" {
  description = "CIDR range for the subnet intended for future externally addressed workloads."
  type        = string
  default     = "10.10.0.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR range for the subnet intended for future private workloads."
  type        = string
  default     = "10.10.1.0/24"
}

variable "private_services_cidr" {
  description = "Reserved CIDR range for Private Services Access."
  type        = string
  default     = "10.20.0.0/16"
}

variable "sql_instance_name" {
  description = "Name of the Cloud SQL instance."
  type        = string
}

variable "sql_tier" {
  description = "Cloud SQL machine tier."
  type        = string
}

variable "dev_database_password" {
  description = "Password for the ecommerce_dev database user."
  type        = string
  sensitive   = true
}

variable "prod_database_password" {
  description = "Password for the ecommerce_prod database user."
  type        = string
  sensitive   = true
}