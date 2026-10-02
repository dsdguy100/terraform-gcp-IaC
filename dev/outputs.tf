
output "load_balancer_ip" {
  description = "Reserved global IPv4 address for the development HTTP load balancer."
  value       = google_compute_global_address.app.address
}

output "load_balancer_url" {
  description = "HTTP URL for the development Flask application."
  value       = "http://${google_compute_global_address.app.address}"
}

output "app_service_account" {
  description = "Identity metadata for the development application service account."
  value = {
    account_id = google_service_account.app_vm.account_id
    email      = google_service_account.app_vm.email
    unique_id  = google_service_account.app_vm.unique_id
  }
}

output "app_instance_template" {
  description = "Configuration and identifiers for the application instance template."
  value = {
    name           = google_compute_instance_template.app.name
    id             = google_compute_instance_template.app.id
    self_link      = google_compute_instance_template.app.self_link
    machine_type   = google_compute_instance_template.app.machine_type
    app_image      = var.app_image
    boot_disk_size = var.boot_disk_size_gb
    subnet         = data.terraform_remote_state.shared.outputs.subnets.private.self_link
    network_tags   = google_compute_instance_template.app.tags
  }
}

output "app_mig" {
  description = "Regional managed instance group metadata and configured capacity."
  value = {
    name               = google_compute_region_instance_group_manager.app.name
    id                 = google_compute_region_instance_group_manager.app.id
    region             = google_compute_region_instance_group_manager.app.region
    instance_group     = google_compute_region_instance_group_manager.app.instance_group
    base_instance_name = google_compute_region_instance_group_manager.app.base_instance_name
    target_size        = google_compute_region_instance_group_manager.app.target_size
    instance_template  = google_compute_region_instance_group_manager.app.version[0].instance_template
    named_ports        = google_compute_region_instance_group_manager.app.named_port
  }
}

output "app_autoscaler" {
  description = "Autoscaler metadata and configured scaling policy."
  value = {
    name         = google_compute_region_autoscaler.app.name
    id           = google_compute_region_autoscaler.app.id
    region       = google_compute_region_autoscaler.app.region
    target       = google_compute_region_autoscaler.app.target
    min_replicas = var.min_replicas
    max_replicas = var.max_replicas
    cpu_target   = var.cpu_target
  }
}

output "app_health_check" {
  description = "HTTP health check configuration used for the application MIG and load balancer."
  value = {
    name                = google_compute_health_check.app.name
    id                  = google_compute_health_check.app.id
    check_interval_sec  = google_compute_health_check.app.check_interval_sec
    timeout_sec         = google_compute_health_check.app.timeout_sec
    healthy_threshold   = google_compute_health_check.app.healthy_threshold
    unhealthy_threshold = google_compute_health_check.app.unhealthy_threshold
    http_port           = google_compute_health_check.app.http_health_check[0].port
    request_path        = google_compute_health_check.app.http_health_check[0].request_path
  }
}

output "load_balancer_resources" {
  description = "HTTP load balancer resource inventory; the endpoint is the reserved global IP."
  value = {
    global_address = {
      name    = google_compute_global_address.app.name
      id      = google_compute_global_address.app.id
      address = google_compute_global_address.app.address
    }
    forwarding_rule = {
      name       = google_compute_global_forwarding_rule.app.name
      id         = google_compute_global_forwarding_rule.app.id
      ip_address = google_compute_global_forwarding_rule.app.ip_address
      protocol   = google_compute_global_forwarding_rule.app.ip_protocol
      port_range = google_compute_global_forwarding_rule.app.port_range
      target     = google_compute_global_forwarding_rule.app.target
    }
    target_http_proxy = {
      name    = google_compute_target_http_proxy.app.name
      id      = google_compute_target_http_proxy.app.id
      url_map = google_compute_target_http_proxy.app.url_map
    }
    url_map = {
      name            = google_compute_url_map.app.name
      id              = google_compute_url_map.app.id
      default_service = google_compute_url_map.app.default_service
    }
    backend_service = {
      name                  = google_compute_backend_service.app.name
      id                    = google_compute_backend_service.app.id
      protocol              = google_compute_backend_service.app.protocol
      port_name             = google_compute_backend_service.app.port_name
      load_balancing_scheme = google_compute_backend_service.app.load_balancing_scheme
      instance_groups       = [for backend in google_compute_backend_service.app.backend : backend.group]
      health_checks         = google_compute_backend_service.app.health_checks
    }
  }
}

output "secret_access_resources" {
  description = "Secret identifiers and explicit accessor grants; secret payloads are not exposed."
  value = {
    database_password_secret_id = data.terraform_remote_state.shared.outputs.dev_database_password_secret_id
    flask_session_secret_id     = google_secret_manager_secret.flask_session.id
    flask_session_version_name  = google_secret_manager_secret_version.flask_session.name
    database_password_accessor = {
      id        = google_secret_manager_secret_iam_member.database_password_reader.id
      secret_id = google_secret_manager_secret_iam_member.database_password_reader.secret_id
      member    = google_secret_manager_secret_iam_member.database_password_reader.member
      role      = google_secret_manager_secret_iam_member.database_password_reader.role
    }
    flask_session_accessor = {
      id        = google_secret_manager_secret_iam_member.flask_session_reader.id
      secret_id = google_secret_manager_secret_iam_member.flask_session_reader.secret_id
      member    = google_secret_manager_secret_iam_member.flask_session_reader.member
      role      = google_secret_manager_secret_iam_member.flask_session_reader.role
    }
  }
}