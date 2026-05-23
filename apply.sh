#!/bin/bash
set -euo pipefail

./check_env.sh

terraform -chdir=01-mig init
terraform -chdir=01-mig apply -auto-approve || true
# Nasty race condition - Simple work around
terraform -chdir=01-mig apply -auto-approve 

./validate.sh
