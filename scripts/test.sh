#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="${1:-0}"

# Change to project root
cd "$(dirname "${BASH_SOURCE[0]}")/.."


# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

bash scripts/test-setup.sh "$PROJECT_ROOT"
bash scripts/test-deploy.sh "$PROJECT_ROOT"