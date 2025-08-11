#!/bin/bash
set -e

# System test for security validation - validates security configurations
# This test runs from within the artifact and validates security settings

ARTIFACT_ROOT="${1:-build}"

echo "=== System Test: Security ==="
echo "Testing security configurations in: $ARTIFACT_ROOT"

# Ensure we're working in the artifact directory
if [ ! -d "$ARTIFACT_ROOT" ]; then
    echo "ERROR: Artifact directory $ARTIFACT_ROOT not found"
    exit 1
fi

cd "$ARTIFACT_ROOT"

# Run setup first to ensure env files exist
echo "Running setup to prepare environment..."
chmod +x scripts/setup.sh
./scripts/setup.sh

# Validate that secrets are generated and not empty
echo "Validating generated secrets..."
if [ -f "env/.env.postgres" ]; then
    if grep -q "POSTGRES_PASSWORD=$" env/.env.postgres; then
        echo "ERROR: POSTGRES_PASSWORD is empty"
        exit 1
    fi
fi

if [ -f "env/.env.n8n" ]; then
    if grep -q "N8N_ENCRYPTION_KEY=$" env/.env.n8n; then
        echo "ERROR: N8N_ENCRYPTION_KEY is empty"
        exit 1
    fi
fi

# Validate file permissions
echo "Validating file permissions..."
if [ -f "env/.env" ]; then
    perms=$(stat -c "%a" env/.env)
    if [ "$perms" != "600" ] && [ "$perms" != "644" ]; then
        echo "WARNING: env/.env has permissions $perms (should be 600 or 644)"
    fi
fi

# Additional static artifact security checks (merged from top-level test_security.sh)

# Check for hardcoded secrets in docker-compose.yml
if [ -f "docker-compose.yml" ]; then
    echo "Checking for hardcoded secrets in docker-compose.yml..."
    if grep -i "password.*=" docker-compose.yml | grep -v '\${' | grep -v 'POSTGRES_PASSWORD'; then
        echo "FAIL: Found hardcoded password in docker-compose.yml"; exit 1; fi
    if grep -i "secret.*=" docker-compose.yml | grep -v '\${'; then
        echo "FAIL: Found hardcoded secret in docker-compose.yml"; exit 1; fi
    echo "PASS: No hardcoded secrets found"
fi

# Check for security options in docker-compose.yml
if [ -f "docker-compose.yml" ]; then
    echo "Checking for security options in docker-compose.yml..."
    if ! grep -q "no-new-privileges" docker-compose.yml; then
        echo "FAIL: no-new-privileges not found"; exit 1; fi
    if ! grep -q "read_only.*true" docker-compose.yml; then
        echo "FAIL: read_only filesystems not configured"; exit 1; fi
    echo "PASS: Security options are configured"
fi

# Check that scripts are executable but not world-writable
for script in scripts/*.sh; do
    if [ -f "$script" ]; then
        perms=$(stat -c "%a" "$script")
        if [[ "$perms" =~ [0-9][0-9][2367] ]]; then
            echo "FAIL: $script is world-writable ($perms)"; exit 1; fi
    fi
done

echo "PASS: Script file permissions are secure"

echo "✓ Security system test passed"
