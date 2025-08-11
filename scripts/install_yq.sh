#!/usr/bin/env bash
set -euo pipefail

# This script ensures yq is available, downloading it if necessary.

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN_DIR="$PROJECT_ROOT/bin"
export PATH="$BIN_DIR:$PATH"

YQ_VERSION="v4.30.8"
YQ_URL="https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64"

# Create bin directory if it doesn't exist
mkdir -p "$BIN_DIR"

# Check if yq is already installed and in the path
if command -v yq &>/dev/null; then
    echo "[INFO] yq is already installed."
    exit 0
fi

echo "[INFO] yq not found. Downloading yq ${YQ_VERSION}..."

if ! curl -L "$YQ_URL" -o "$BIN_DIR/yq"; then
    echo "[ERROR] Failed to download yq." >&2
    exit 1
fi

chmod +x "$BIN_DIR/yq"

echo "[SUCCESS] yq has been installed to $BIN_DIR/yq"

# Final check
if ! command -v yq &>/dev/null; then
    echo "[ERROR] yq installation failed. Command not found after installation." >&2
    exit 1
fi
