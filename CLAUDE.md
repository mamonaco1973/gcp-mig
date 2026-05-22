# CLAUDE.md — gcp-mig

## What This Project Does

Deploys a minimal GCP Managed Instance Group of Apache web servers behind
a global HTTP(S) Load Balancer. Each instance displays its own metadata
(private IP, instance name, zone, machine type) fetched from the GCP
metadata server on a styled page. Instances are private (no external IP);
outbound access via Cloud NAT.

## Commands

```bash
./apply.sh      # check env, terraform init + apply, then validate
./destroy.sh    # teardown all resources
./validate.sh   # poll LB IP, sample 10 /plain responses
```

## Architecture

Single Terraform phase in `01-mig/`. No modules, no workspaces.

- **Region:** us-central1
- **Instance:** e2-micro (0.25–2 vCPU shared, 1 GB) — cheapest GCP general-purpose
- **LB:** Global HTTP(S) Load Balancer (L7) — per-request routing
- **MIG:** Regional, min 1, desired 4, max 6 across all us-central1 zones
- **Scaling:** Regional autoscaler, CPU-based with scale-in control
- **Auth:** `credentials.json` service account key (gitignored, never committed)
- **Startup:** `scripts/startup.sh` via `metadata.startup-script`

## Scaling Policy

Scale-out reacts within 2 minutes (120s cooldown). Scale-in is limited to
1 instance removed per 1-hour window via `scale_in_control`.

## Critical Patterns

- **Firewall for LB health checks.** GCP's HTTP LB health checkers and proxy
  traffic originate from `130.211.0.0/22` and `35.191.0.0/16`. Instances have
  no public IP, so these ranges must be explicitly allowed on port 80 via a
  firewall rule targeting the `mig-http` network tag. Without this, health
  checks always fail and the MIG never enters the backend pool.

- **No `access_config` on network interface.** Omitting the `access_config {}`
  block in the instance template is what prevents external IP assignment. Cloud
  NAT handles all egress without an external IP on the NIC.

- **`create_before_destroy = true` on instance template.** Required when
  updating a template referenced by a live MIG — avoids a resource name
  conflict during replacement.

- **`lifecycle { ignore_changes = [target_size] }`** on the MIG prevents
  Terraform from overwriting the autoscaler's instance count adjustments on
  re-apply.

- **Health check propagation race.** GCP's API reports the health check as
  ready before the backend service API can actually use it. A `time_sleep`
  resource waits 30 seconds after health check creation before the backend
  service is created. Requires the `hashicorp/time` provider.

- **LB propagation time.** GCP's global HTTP LB takes up to 15 minutes to
  fully propagate after creation. `validate.sh` polls for up to 900 seconds.

- **LB output is a bare IP.** Unlike Azure (DNS label) and AWS (ALB DNS name),
  the GCP LB exposes only a static global IP. `validate.sh` uses this IP
  directly.

## GCP Metadata Server

Endpoint: `http://metadata.google.internal/computeMetadata/v1/`
Required header: `Metadata-Flavor: Google`

Zone and machine-type are returned as full resource paths
(e.g. `projects/123/zones/us-central1-a`). Strip to last component with
`awk -F'/' '{print $NF}'`.

## Key Files

| File | Purpose |
|------|---------|
| `01-mig/mig.tf` | Instance template, regional MIG, autoscaler |
| `01-mig/lb.tf` | Global IP, backend service, URL map, proxy, forwarding rule |
| `01-mig/networking.tf` | VPC, subnet, Cloud Router, Cloud NAT, firewall, health check |
| `01-mig/main.tf` | Google provider, credentials.json wiring |
| `01-mig/scripts/startup.sh` | Installs Apache, fetches GCP metadata, writes HTML + /plain |
