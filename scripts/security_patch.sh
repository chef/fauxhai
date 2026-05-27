#!/bin/bash
# security_patch.sh — Repeatable security hygiene patches for fauxhai
#
# Usage:
#   ./scripts/security_patch.sh [check|apply|revert]
#
# Modes:
#   check   - Report which fixes are already applied (exit 0 if all applied)
#   apply   - Apply all security patches (idempotent)
#   revert  - Revert all security patches
#
# This script can be run in CI to verify security hygiene is maintained.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LIB_DIR="$REPO_ROOT/lib"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

passed=0
failed=0
total=0

report() {
  local status="$1" desc="$2"
  total=$((total + 1))
  if [ "$status" = "PASS" ]; then
    passed=$((passed + 1))
    echo -e "  ${GREEN}✓${NC} $desc"
  else
    failed=$((failed + 1))
    echo -e "  ${RED}✗${NC} $desc"
  fi
}

# --- Check 1: frozen_string_literal pragma ---
check_frozen_string_literal() {
  echo "Check 1: frozen_string_literal pragma on all lib/**/*.rb files"
  local missing=0
  while IFS= read -r f; do
    if ! head -1 "$f" | grep -q "frozen_string_literal: true"; then
      echo -e "    ${YELLOW}Missing:${NC} $f"
      missing=$((missing + 1))
    fi
  done < <(find "$LIB_DIR" -name "*.rb" -type f)
  if [ "$missing" -eq 0 ]; then
    report "PASS" "All lib/*.rb files have frozen_string_literal: true"
  else
    report "FAIL" "$missing file(s) missing frozen_string_literal pragma"
  fi
}

apply_frozen_string_literal() {
  while IFS= read -r f; do
    if ! head -1 "$f" | grep -q "frozen_string_literal: true"; then
      # macOS-compatible sed: insert pragma before first line
      sed -i '' '1s/^/# frozen_string_literal: true\n\n/' "$f"
      echo "  Applied frozen_string_literal to $f"
    fi
  done < <(find "$LIB_DIR" -name "*.rb" -type f)
}

revert_frozen_string_literal() {
  while IFS= read -r f; do
    if head -1 "$f" | grep -q "frozen_string_literal: true"; then
      # Remove the pragma line and the blank line after it
      sed -i '' '1{/^# frozen_string_literal: true$/d;}' "$f"
      sed -i '' '1{/^$/d;}' "$f"
      echo "  Reverted frozen_string_literal from $f"
    fi
  done < <(find "$LIB_DIR" -name "*.rb" -type f)
}

# --- Check 2: No unused digest/sha1 import ---
check_no_sha1_import() {
  echo "Check 2: No unused require 'digest/sha1'"
  if grep -r "require.*digest/sha1" "$LIB_DIR" --include="*.rb" -l 2>/dev/null; then
    report "FAIL" "Found unused require 'digest/sha1'"
  else
    report "PASS" "No unused digest/sha1 imports"
  fi
}

# --- Check 3: Input validation on platform/version ---
check_input_validation() {
  echo "Check 3: Platform/version input validation present"
  if grep -q "SAFE_IDENTIFIER" "$LIB_DIR/fauxhai/mocker.rb"; then
    report "PASS" "SAFE_IDENTIFIER validation present in mocker.rb"
  else
    report "FAIL" "Missing SAFE_IDENTIFIER validation in mocker.rb"
  fi
  if grep -q "validate_identifier!" "$LIB_DIR/fauxhai/mocker.rb"; then
    report "PASS" "validate_identifier! method present in mocker.rb"
  else
    report "FAIL" "Missing validate_identifier! method in mocker.rb"
  fi
}

# --- Main ---
MODE="${1:-check}"

echo ""
echo "=== Fauxhai Security Hygiene Scanner ==="
echo "Mode: $MODE"
echo ""

case "$MODE" in
  check)
    check_frozen_string_literal
    check_no_sha1_import
    check_input_validation
    echo ""
    echo "Results: $passed/$total checks passed"
    [ "$failed" -eq 0 ] && exit 0 || exit 1
    ;;
  apply)
    echo "Applying security patches..."
    apply_frozen_string_literal
    check_frozen_string_literal
    check_no_sha1_import
    check_input_validation
    echo ""
    echo "Results: $passed/$total checks passed"
    ;;
  revert)
    echo "Reverting security patches..."
    revert_frozen_string_literal
    echo "  Note: digest/sha1 and input validation reverts require git checkout"
    echo "  Run: git checkout -- lib/fauxhai/fetcher.rb lib/fauxhai/mocker.rb"
    ;;
  *)
    echo "Usage: $0 [check|apply|revert]"
    exit 1
    ;;
esac
