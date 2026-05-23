#!/bin/bash
# ================================================================================
# check_env.sh
# Validates that required CLI tools are installed and credentials.json is
# present before attempting a terraform apply.
# ================================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# Tool Checks
# ------------------------------------------------------------------------------

echo "NOTE: Validating that required commands are found in the PATH."

commands=("gcloud" "terraform")
all_found=true

for cmd in "${commands[@]}"; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "ERROR: $cmd is not found in the current PATH."
    all_found=false
  else
    echo "NOTE: $cmd is found in the current PATH."
  fi
done

if [ "$all_found" = false ]; then
  echo "ERROR: One or more required commands are missing."
  exit 1
fi

echo "NOTE: All required commands are available."

# ------------------------------------------------------------------------------
# Credentials
# The GCP provider and all Terraform resources authenticate via this key file.
# ------------------------------------------------------------------------------

if [[ ! -f "./credentials.json" ]]; then
  echo "ERROR: ./credentials.json not found. Generate a service account key and place it here."
  exit 1
fi

echo "NOTE: credentials.json found."
gcloud auth activate-service-account --key-file="./credentials.json"
echo "NOTE: Service account activated successfully."

# ------------------------------------------------------------------------------
# API Setup
# Enable required GCP APIs before Terraform runs — idempotent, safe to re-run.
# ------------------------------------------------------------------------------

./api_setup.sh
