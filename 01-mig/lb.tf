# ================================================================================
# HTTP Load Balancer
# GCP's global HTTP(S) LB is the equivalent of Azure Application Gateway — both
# are Layer 7 and route each request independently, giving even distribution
# across instances regardless of persistent TCP connections.
#
# The chain is: Global Forwarding Rule → Target HTTP Proxy → URL Map →
# Backend Service → Instance Group
# ================================================================================

# Static global IP — stable across redeployments, referenced in validate.sh
resource "google_compute_global_address" "lb_ip" {
  name = "mig-lb-ip"
}

# Backend service connects the LB to the MIG. UTILIZATION balancing mode
# distributes requests based on instance CPU load rather than connection count.
resource "google_compute_backend_service" "main" {
  name                  = "mig-backend-service"
  protocol              = "HTTP"

  # Matches the named_port declared on the instance group manager
  port_name             = "http"
  health_checks         = [google_compute_health_check.http.self_link]
  timeout_sec           = 30
  load_balancing_scheme = "EXTERNAL"

  backend {
    group          = google_compute_region_instance_group_manager.main.instance_group
    balancing_mode = "UTILIZATION"
  }
}

resource "google_compute_url_map" "main" {
  name            = "mig-lb"
  default_service = google_compute_backend_service.main.self_link
}

resource "google_compute_target_http_proxy" "main" {
  name    = "mig-http-proxy"
  url_map = google_compute_url_map.main.id
}

resource "google_compute_global_forwarding_rule" "main" {
  name                  = "mig-forwarding-rule"
  ip_address            = google_compute_global_address.lb_ip.address
  target                = google_compute_target_http_proxy.main.self_link
  port_range            = "80"
  load_balancing_scheme = "EXTERNAL"
}
