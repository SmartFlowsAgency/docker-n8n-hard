#!/bin/bash
# Artifact/Integration Test: build artifact content
set -e

ARTIFACT_ROOT="${1:-dist}"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACT_PATH="$PROJECT_ROOT/$ARTIFACT_ROOT"

assert_file_exists() {
    if [ ! -f "$1" ]; then
        echo "FAIL: File '$1' does not exist"
        exit 1
    fi
}

assert_dir_exists() {
    if [ ! -d "$1" ]; then
        echo "FAIL: Directory '$1' does not exist"
        exit 1
    fi
}

# Check for key runtime files
assert_file_exists "$ARTIFACT_PATH/docker-compose.yml"
assert_file_exists "$ARTIFACT_PATH/dn8nh.sh"
assert_dir_exists "$ARTIFACT_PATH/scripts"
assert_dir_exists "$ARTIFACT_PATH/entrypoints"
assert_dir_exists "$ARTIFACT_PATH/env"
assert_dir_exists "$ARTIFACT_PATH/nginx-conf"

# Check for at least one script
assert_file_exists "$ARTIFACT_PATH/scripts/setup.sh"

# Optionally, check for README
assert_file_exists "$ARTIFACT_PATH/README.md"

echo "[PASS] build artifact content test from $ARTIFACT_ROOT"
