output "lb_ip" {
  description = "Global static IP address of the HTTP load balancer"
  value       = google_compute_global_address.lb_ip.address
}
