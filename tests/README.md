# Top-Level Test Suite: Artifact & Integration Tests

This directory contains acceptance, integration, and artifact portability tests for the n8n-hardened project.

## Structure
- Place all tests that validate the built artifacts (`dist/`, `build/`) here.
- Tests here should:
  - Assume no access to parent or sibling directories (simulate end-user environment)
  - Accept a base directory argument (`dist` or `build`)
  - Validate setup, deploy, config, and integration workflows

## Example Tests
- `test_setup.sh` — Validates setup script from artifact
- `test_deploy.sh` — Validates deploy script from artifact
- `test_config.sh` — Validates docker-compose, envs, and config completeness

## Usage
Run from project root:
```sh
for ARTIFACT in dist build; do
  tests/test_setup.sh $ARTIFACT
  tests/test_deploy.sh $ARTIFACT
  tests/test_config.sh $ARTIFACT
  # ...
done
```

## Test Execution

- Run all artifact/integration tests with `../test.sh` from the workspace root.
- These tests are run automatically in CI.

## Developer/Unit Tests

- Developer/unit tests live in `src/tests/` and are run with `bash dev_test.sh`. This is currently a stub.
- These tests are also run in CI, but may be expanded in the future.

## Maintenance
- Keep dev/unit tests in `src/tests/` if needed
- Update this README as test coverage evolves
