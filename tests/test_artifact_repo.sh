#!/usr/bin/env bash
# test_artifact_repo.sh: Validate artifact repo after release

set -euo pipefail

ARTIFACT_REPO_SSH="git@github.com:SmartFlowsAgency/docker-n8n-hard.git"
ARTIFACT_CLONE_DIR="artifact-repo-test"
EXPECTED_FILES=("scripts/setup.sh" "scripts/deploy.sh" "scripts/backup.sh" "README.md") # Add more as needed

# 1. Clone the artifact repo
rm -rf "$ARTIFACT_CLONE_DIR"
git clone --depth=1 "$ARTIFACT_REPO_SSH" "$ARTIFACT_CLONE_DIR"

cd "$ARTIFACT_CLONE_DIR"

# 2. Check for expected files
echo "Checking for expected files in artifact repo..."
for file in "${EXPECTED_FILES[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "❌ Missing expected file: $file"
    exit 1
  else
    echo "✅ Found: $file"
  fi
done

# 3. (Optional) Run smoke tests
if [[ -x ./setup.sh ]]; then
  echo "Running smoke test: ./setup.sh --help"
  ./setup.sh --help || { echo "❌ setup.sh failed smoke test"; exit 1; }
fi

echo "All artifact repo checks passed."
