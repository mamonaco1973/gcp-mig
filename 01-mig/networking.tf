# ================================================================================
# VPC and Subnet
# Custom VPC with a single subnet — instances live here with no external IPs.
# Cloud NAT provides egress-only internet access for startup script package
# installation without exposing instances directly to the internet.
# ================================================================================

resource "google_compute_network" "main" {
  name                    = "mig-vpc"

  # Prevent GCP from auto-creating a subnet in every region
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "main" {
  name          = "mig-subnet"
  ip_cidr_range = "10.0.1.0/24"
  region        = "us-central1"
  network       = google_compute_network.main.id
}

# ================================================================================
# Cloud Router and NAT
# Cloud NAT is the GCP equivalent of Azure NAT Gateway — it provides shared
# egress IPs for instances that have no external IP on their NIC. Required so
# apt-get can reach the internet during startup script execution.
# ================================================================================

resource "google_compute_router" "main" {
  name    = "mig-router"
  network = google_compute_network.main.id
  region  = "us-central1"
}

resource "google_compute_router_nat" "main" {
  name                               = "mig-nat"
  router                             = google_compute_router.main.name
  region                             = "us-central1"
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

# ================================================================================
# Firewall Rules
# GCP's HTTP(S) Load Balancer health checkers and proxy traffic originate from
# 130.211.0.0/22 and 35.191.0.0/16 — these ranges must reach port 80 on
# instances even though instances have no public IP.
# ================================================================================

resource "google_compute_firewall" "allow_lb" {
  name    = "mig-allow-lb"
  network = google_compute_network.main.id

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  # GCP health checker and LB proxy source ranges — not user traffic
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
  target_tags   = ["mig-http"]
}

# ================================================================================
# Health Check
# HTTP health check on / at port 80. The 10-second interval matches the Azure
# App Gateway probe cadence for consistency across the two demos.
# ================================================================================

resource "google_compute_health_check" "http" {
  name                = "mig-health-check"
  check_interval_sec  = 10
  timeout_sec         = 10
  healthy_threshold   = 2
  unhealthy_threshold = 2

  http_health_check {
    request_path = "/"
    port         = 80
  }
}
