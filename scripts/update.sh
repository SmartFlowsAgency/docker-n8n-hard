#!/bin/bash
# update.sh - One-click update to latest version or specific release
# Usage: ./update.sh [version] [--dry-run]
#
# Examples:
#   ./update.sh              # Update to latest version
#   ./update.sh v1.2.3       # Update to specific version
#   ./update.sh --dry-run     # Show what would be updated

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "\n${BLUE}▶${NC} $1"; }

# Configuration
ARTIFACT_REPO_URL="https://github.com/SmartFlowsAgency/docker-n8n-hard-src.git"
BRANCH="main"
DRY_RUN=false
TARGET_VERSION=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            log_info "DRY RUN MODE - No changes will be made"
            shift
            ;;
        v*)
            TARGET_VERSION="$1"
            log_info "Target version: $TARGET_VERSION"
            shift
            ;;
        -*)
            log_error "Unknown option: $1"
            echo "Usage: $0 [version] [--dry-run]"
            exit 1
            ;;
        *)
            log_error "Unexpected argument: $1"
            echo "Usage: $0 [version] [--dry-run]"
            exit 1
            ;;
    esac
done

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    log_error "Not in a git repository. Please clone the repository first."
    exit 1
fi

# Check if artifact repo is configured as remote
if ! git remote get-url origin 2>/dev/null | grep -q "docker-n8n-hard"; then
    log_warn "Artifact repository not configured as 'origin' remote"
    log_warn "Consider adding it: git remote add origin $ARTIFACT_REPO_URL"
fi

log_step "Checking current status..."

# Show current version/status
CURRENT_BRANCH=$(git branch --show-current)
CURRENT_COMMIT=$(git rev-parse --short HEAD)
log_info "Current branch: $CURRENT_BRANCH"
log_info "Current commit: $CURRENT_COMMIT"

if [ -n "$TARGET_VERSION" ]; then
    log_step "Fetching specific version: $TARGET_VERSION"
    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY RUN] Would fetch and checkout version: $TARGET_VERSION"
        log_info "[DRY RUN] Command: git fetch origin $TARGET_VERSION"
        log_info "[DRY RUN] Command: git checkout $TARGET_VERSION"
    else
        if git fetch origin "$TARGET_VERSION" 2>/dev/null; then
            git checkout "$TARGET_VERSION"
            NEW_COMMIT=$(git rev-parse --short HEAD)
            log_info "✅ Updated to version $TARGET_VERSION (commit: $NEW_COMMIT)"
        else
            log_error "Version $TARGET_VERSION not found in remote repository"
            exit 1
        fi
    fi
else
    log_step "Updating to latest version..."
    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY RUN] Would fetch latest changes and merge/rebase"
        log_info "[DRY RUN] Command: git fetch origin"
        log_info "[DRY RUN] Command: git merge origin/$BRANCH"
    else
        # Fetch latest changes
        git fetch origin

        # Check if there are updates available
        LOCAL=$(git rev-parse HEAD)
        REMOTE=$(git rev-parse origin/$BRANCH)

        if [ "$LOCAL" = "$REMOTE" ]; then
            log_info "✅ Already up to date"
            exit 0
        fi

        # Update to latest
        git merge origin/$BRANCH
        NEW_COMMIT=$(git rev-parse --short HEAD)
        log_info "✅ Updated to latest version (commit: $NEW_COMMIT)"
    fi
fi

log_step "Update complete!"

if [ "$DRY_RUN" = false ]; then
    echo
    log_warn "Next steps:"
    log_warn "1. Review changes: git log --oneline HEAD~5..HEAD"
    log_warn "2. Run setup: ./scripts/setup.sh"
    log_warn "3. Deploy: ./scripts/deploy.sh"
    echo
    log_info "🎉 Update successful! Ready to deploy updated version."
else
    log_info "[DRY RUN] No changes made - run without --dry-run to apply updates"
fi
