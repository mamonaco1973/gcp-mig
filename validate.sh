#!/bin/bash
# ================================================================================
# validate.sh
# ================================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# Step 1: Resolve LB IP from Terraform output
# ------------------------------------------------------------------------------

LB_IP=$(terraform -chdir=01-mig output -raw lb_ip 2>/dev/null || true)

if [ -z "${LB_IP}" ]; then
  echo "ERROR: Could not read Terraform outputs. Run ./apply.sh first."
  exit 1
fi

echo "NOTE: Load balancer endpoint: http://${LB_IP}"

# ------------------------------------------------------------------------------
# Step 2: Wait for HTTP response from the load balancer
# GCP's global HTTP LB and instance startup both take time — poll until ready
# ------------------------------------------------------------------------------

echo "NOTE: Waiting for HTTP 200 from load balancer..."

TIMEOUT=900
ELAPSED=0

while true; do
  HTTP_CODE=$(curl -o /dev/null -s -w "%{http_code}" --max-time 5 \
    "http://${LB_IP}/plain" 2>/dev/null || echo "000")

  if [ "${HTTP_CODE}" = "200" ]; then
    echo "NOTE: Load balancer returned HTTP 200."
    break
  fi

  if [ "${ELAPSED}" -ge "${TIMEOUT}" ]; then
    echo "ERROR: Timed out waiting for HTTP 200 after ${TIMEOUT}s."
    exit 1
  fi

  echo "NOTE: HTTP ${HTTP_CODE} — retrying in 30s (${ELAPSED}s elapsed)..."
  sleep 30
  ELAPSED=$((ELAPSED + 30))
done

# ------------------------------------------------------------------------------
# Step 3: Sample responses
# Different IPs across requests confirm per-request load balancing is working
# ------------------------------------------------------------------------------

echo "NOTE: Sampling load balancer responses..."
echo ""

for i in $(seq 1 10); do
  RESPONSE=$(curl -sf "http://${LB_IP}/plain")
  echo "  [${i}] ${RESPONSE}"
done

echo ""
echo "================================================================================="
echo "  Managed Instance Group — Deployment validated!"
echo "================================================================================="
echo "  LB : http://${LB_IP}"
echo "================================================================================="
