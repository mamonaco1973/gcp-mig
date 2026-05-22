# ================================================================================
# Instance Template
# Defines the blueprint for every instance the MIG creates. The startup script
# is passed inline — no Packer image needed for a simple Apache workload.
# e2-micro is the cheapest GCP general-purpose instance, analogous to B1s in
# Azure. Unlike AWS Graviton, GCP ARM (t2a) starts at 1 vCPU at similar cost
# so e2-micro remains the cheapest option for small demo workloads.
# ================================================================================

resource "google_compute_instance_template" "main" {
  name         = "mig-template"
  machine_type = "e2-micro"

  # Tag drives the mig-allow-lb firewall rule — without this tag instances
  # cannot receive traffic from the LB health checkers or proxy
  tags = ["mig-http"]

  disk {
    auto_delete  = true
    boot         = true

    # Ubuntu 22.04 LTS — matches the Azure VMSS demo for consistency
    source_image = "ubuntu-os-cloud/ubuntu-2204-lts"
  }

  network_interface {
    network    = google_compute_network.main.id
    subnetwork = google_compute_subnetwork.main.id

    # No access_config block — instances get no external IP.
    # Cloud NAT (mig-nat) provides egress-only internet for apt-get.
  }

  metadata = {
    startup-script = file("${path.module}/scripts/startup.sh")
  }

  service_account {
    # cloud-platform scope is broad but avoids needing per-API scope tuning
    # for a demo that only reads instance metadata
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  # Required when updating a template referenced by a running MIG — creates the
  # new template before destroying the old one to avoid a resource name conflict
  lifecycle {
    create_before_destroy = true
  }
}

# ================================================================================
# Managed Instance Group
# Regional MIG automatically distributes instances across all zones in
# us-central1, equivalent to the Azure VMSS zone spread across zones 1 and 2.
# Auto-healing replaces instances that fail health checks.
# ================================================================================

resource "google_compute_region_instance_group_manager" "main" {
  name               = "mig-main"
  base_instance_name = "mig-instance"
  region             = "us-central1"

  # Initial count — autoscaler adjusts this after first apply
  target_size = 4

  version {
    instance_template = google_compute_instance_template.main.self_link
  }

  # Named port binds the backend service port_name "http" to port 80 on
  # instances — required for the LB to forward traffic correctly
  named_port {
    name = "http"
    port = 80
  }

  auto_healing_policies {
    health_check = google_compute_health_check.http.self_link

    # Give instances 120 seconds to finish the startup script and start apache2
    # before auto-healing begins replacing them
    initial_delay_sec = 120
  }

  lifecycle {
    # Autoscaler adjusts target_size at runtime — ignoring prevents Terraform
    # from fighting autoscaler on every subsequent plan
    ignore_changes = [target_size]
  }
}

# ================================================================================
# Autoscaler
# CPU-based rules mirror the Azure Monitor autoscale pattern. scale_in_control
# limits removal to 1 instance per hour — the long window prevents scale-in
# during demos or brief CPU dips between requests.
# ================================================================================

resource "google_compute_region_autoscaler" "main" {
  name   = "mig-autoscaler"
  target = google_compute_region_instance_group_manager.main.self_link
  region = "us-central1"

  autoscaling_policy {
    max_replicas = 6
    min_replicas = 1

    # 2-minute cooldown prevents a second scale-out before the first wave of
    # new instances has absorbed the load
    cooldown_period = 120

    cpu_utilization {
      target = 0.6
    }

    # Allow at most 1 instance to be removed within any 1-hour window.
    # Prevents aggressive scale-in during demos and brief quiet periods.
    scale_in_control {
      time_window_sec = 3600
      max_scaled_in_replicas {
        fixed = 1
      }
    }
  }
}
