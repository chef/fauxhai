#!/usr/bin/env bash
# scripts/rubocop_autofix.sh — Repeatable RuboCop autofix for chef/fauxhai
#
# Usage:
#   ./scripts/rubocop_autofix.sh              # Auto-correct lib/ and spec/
#   ./scripts/rubocop_autofix.sh --dry-run    # Show what would change (no writes)
#   ./scripts/rubocop_autofix.sh lib/         # Target a specific path
#
# Prerequisites:
#   gem install rubocop  (or: bundle exec prefix is auto-detected)
#
# What this script does:
#   1. Runs RuboCop safe auto-correct (-A) on the target paths
#   2. Reports before/after offense counts
#   3. Exits non-zero if any offenses remain after auto-correct
#
# Safe auto-correct only applies fixes that do not change program semantics.
# Manual review is still recommended after running.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

# Detect bundler
if command -v bundle >/dev/null 2>&1 && [ -f Gemfile ]; then
  RUBOCOP="bundle exec rubocop"
else
  RUBOCOP="rubocop"
fi

# Default target paths
TARGETS=("lib/" "spec/" "scripts/" "Rakefile" "Gemfile")
DRY_RUN=false

# Parse arguments
for arg in "$@"; do
  case "$arg" in
    --dry-run)
      DRY_RUN=true
      ;;
    *)
      TARGETS=("$arg")
      ;;
  esac
done

echo "=== RuboCop Autofix Script ==="
echo "Target paths: ${TARGETS[*]}"
echo ""

# Capture baseline
echo "--- Baseline (before autofix) ---"
BASELINE=$($RUBOCOP "${TARGETS[@]}" --format simple 2>&1 | tail -1 || true)
echo "$BASELINE"
echo ""

if $DRY_RUN; then
  echo "--- Dry run: showing what would change ---"
  $RUBOCOP "${TARGETS[@]}" --autocorrect-all --dry-run --format simple 2>&1 || true
  exit 0
fi

# Run safe auto-correct
echo "--- Running safe auto-correct (-A) ---"
$RUBOCOP "${TARGETS[@]}" --autocorrect-all --format simple 2>&1 || true
echo ""

# Capture post-fix count
echo "--- After autofix ---"
AFTER=$($RUBOCOP "${TARGETS[@]}" --format simple 2>&1 | tail -1 || true)
echo "$AFTER"
echo ""

echo "=== Summary ==="
echo "Before: $BASELINE"
echo "After:  $AFTER"

# Exit non-zero if offenses remain
if echo "$AFTER" | grep -q "no offenses"; then
  echo "All clean!"
  exit 0
else
  echo "Some offenses remain — review manually or add suppressions."
  exit 1
fi
