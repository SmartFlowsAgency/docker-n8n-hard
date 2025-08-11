#!/usr/bin/env bash
#
# Test script to verify setup functionality for n8n-hardened artifact
#

set -euo pipefail

# Change to project root
d=$(dirname "${BASH_SOURCE[0]}")
cd "$d/.."

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[TEST]${NC} $1"; }
log_error() { echo -e "${RED}[TEST ERROR]${NC} $1"; }
log_step() { echo -e "\n${BLUE}▶${NC} $1"; }

# 1. Run setup script and check for errors
NO_INTERACTIVE_FLAG=""
if [[ "${1:-}" == "--no-interactive" ]]; then
  NO_INTERACTIVE_FLAG="--no-interactive"
fi

log_step "Running setup.sh to generate build/dist artifacts..."
bash scripts/setup.sh ${NO_INTERACTIVE_FLAG}

log_info "Setup test completed successfully."