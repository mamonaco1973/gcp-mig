#!/bin/bash
set -euo pipefail

terraform -chdir=01-mig destroy -auto-approve
