#!/bin/bash
# ================================================================================
# api_setup.sh
# Enables GCP APIs required by gcp-mig before Terraform runs. Safe to re-run —
# enabling an already-enabled API is a no-op.
# ================================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# Project Configuration
# Extract project ID from credentials.json rather than hard-coding it, so the
# script works across environments without modification.
# ------------------------------------------------------------------------------

project_id=$(jq -r '.project_id' "./credentials.json")

gcloud config set project "$project_id"

# ------------------------------------------------------------------------------
# API Enablement
# Compute covers VMs, MIG, LB, firewall, Cloud NAT, and Cloud Router.
# cloudresourcemanager is required by the Terraform Google provider to resolve
# project metadata. iam is required for service account operations on instances.
# ------------------------------------------------------------------------------

echo "NOTE: Enabling required GCP APIs for project $project_id."

gcloud services enable compute.googleapis.com
gcloud services enable cloudresourcemanager.googleapis.com
gcloud services enable iam.googleapis.com

echo "NOTE: All required APIs are enabled."
