#!/bin/bash
set -e

# Unit test for deploy.sh: check_env_and_config function
# Tests that deploy.sh fails if env/.env is missing

# Resolve absolute path to deploy.sh relative to this test file
TEST_FILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_SCRIPT="$TEST_FILE_DIR/../../src/scripts/deploy.sh"

# Create a temp test directory
TEST_DIR=$(mktemp -d)
cd "$TEST_DIR"
mkdir -p env nginx-conf scripts
cp "$DEPLOY_SCRIPT" scripts/

# Ensure no .env exists to simulate missing file
rm -f .env

# Execute deploy.sh and expect non-zero due to missing .env
set +e
bash scripts/deploy.sh
exit_code=$?
set -e

if [ $exit_code -ne 0 ]; then
  echo "PASS: deploy.sh fails as expected when .env is missing"
else
  echo "FAIL: deploy.sh should fail when .env is missing"
  exit 1
fi

cd /
rm -rf "$TEST_DIR"
