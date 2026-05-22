#!/bin/bash
# ================================================================================
# Startup Script
# Runs as root on first boot. Installs Apache, fetches instance metadata from
# the GCP metadata server, and writes a styled HTML page identical in layout to
# the Azure VMSS demo. Also writes a /plain text file for validate.sh.
# ================================================================================

set -euo pipefail

apt-get update -y
apt-get install -y apache2 jq

# ------------------------------------------------------------------------------
# Fetch instance metadata
# GCP metadata server requires the Metadata-Flavor: Google header. Zone and
# machine-type are returned as full resource paths — strip to last component.
# ------------------------------------------------------------------------------

METADATA="http://metadata.google.internal/computeMetadata/v1"
HEADER="Metadata-Flavor: Google"

IP=$(curl -sf -H "$HEADER" "$METADATA/instance/network-interfaces/0/ip")
VM_NAME=$(curl -sf -H "$HEADER" "$METADATA/instance/name")
ZONE_FULL=$(curl -sf -H "$HEADER" "$METADATA/instance/zone")
ZONE=$(echo "$ZONE_FULL" | awk -F'/' '{print $NF}')
MACHINE_FULL=$(curl -sf -H "$HEADER" "$METADATA/instance/machine-type")
MACHINE_TYPE=$(echo "$MACHINE_FULL" | awk -F'/' '{print $NF}')

# ------------------------------------------------------------------------------
# Write HTML page
# GCP blue (#4285F4) replaces Azure blue — everything else matches the
# Azure VMSS page layout for a consistent cross-cloud demo look.
# ------------------------------------------------------------------------------

cat > /var/www/html/index.html << EOF
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
  <title>GCP MIG Instance</title>
  <style>
    body {
      margin: 0;
      padding: 40px 20px;
      background-color: #ffffff;
      font-family: 'Segoe UI', Arial, sans-serif;
      display: flex;
      justify-content: center;
      align-items: flex-start;
    }
    .card {
      background-color: #232F3E;
      color: #ffffff;
      border-radius: 12px;
      padding: 36px 40px;
      max-width: 520px;
      width: 100%;
      box-shadow: 0 8px 24px rgba(0,0,0,0.15);
    }
    .logo {
      display: flex;
      align-items: center;
      gap: 12px;
      margin-bottom: 28px;
    }
    .logo-icon {
      width: 40px;
      height: 40px;
      background: #4285F4;
      border-radius: 8px;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 20px;
    }
    .logo-text {
      font-size: 20px;
      font-weight: 600;
      color: #4285F4;
    }
    h1 {
      font-size: 22px;
      font-weight: 600;
      margin: 0 0 24px 0;
      color: #ffffff;
    }
    .info-grid {
      display: grid;
      grid-template-columns: 140px 1fr;
      gap: 12px 16px;
      font-size: 15px;
    }
    .label {
      color: #9CA3AF;
      font-weight: 500;
    }
    .value {
      color: #F9FAFB;
      font-weight: 600;
      word-break: break-all;
    }
    .badge {
      display: inline-block;
      background: #4285F4;
      color: white;
      font-size: 11px;
      font-weight: 700;
      padding: 2px 8px;
      border-radius: 4px;
      letter-spacing: 0.5px;
      text-transform: uppercase;
      margin-bottom: 20px;
    }
  </style>
</head>
<body>
  <div class="card">
    <div class="logo">
      <div class="logo-icon">&#9729;</div>
      <div class="logo-text">Google Cloud Platform</div>
    </div>
    <span class="badge">Managed Instance Group</span>
    <h1>Instance Details</h1>
    <div class="info-grid">
      <span class="label">Private IP</span>
      <span class="value">${IP}</span>
      <span class="label">Instance Name</span>
      <span class="value">${VM_NAME}</span>
      <span class="label">Zone</span>
      <span class="value">${ZONE}</span>
      <span class="label">Machine Type</span>
      <span class="value">${MACHINE_TYPE}</span>
    </div>
  </div>
</body>
</html>
EOF

# Plain-text endpoint — validate.sh reads this instead of parsing HTML
echo "$IP" > /var/www/html/plain

systemctl enable apache2
systemctl start apache2
