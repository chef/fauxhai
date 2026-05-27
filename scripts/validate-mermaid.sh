#!/usr/bin/env bash
# scripts/validate-mermaid.sh
# Validates that all Mermaid diagrams in docs/ render without errors.
# Requires: @mermaid-js/mermaid-cli (mmdc)
#
# Install dependency:
#   npm install @mermaid-js/mermaid-cli
#
# Usage:
#   ./scripts/validate-mermaid.sh [file ...]
#   If no files given, validates all *.md files under docs/.

set -euo pipefail

if command -v mmdc &>/dev/null; then
  MMDC="mmdc"
elif [ -x "node_modules/.bin/mmdc" ]; then
  MMDC="node_modules/.bin/mmdc"
else
  echo "Error: mmdc not found. Install with: npm install @mermaid-js/mermaid-cli"
  exit 1
fi

ERRORS=0

# Collect target files
if [ $# -gt 0 ]; then
  FILES=("$@")
else
  FILES=()
  while IFS= read -r -d '' f; do
    FILES+=("$f")
  done < <(find docs -name '*.md' -print0 2>/dev/null)
fi

if [ ${#FILES[@]} -eq 0 ]; then
  echo "No markdown files found to validate."
  exit 0
fi

TMPDIR_WORK="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_WORK"' EXIT

for md_file in "${FILES[@]}"; do
  echo "Checking $md_file …"

  # Extract mermaid code blocks
  BLOCK_NUM=0
  IN_BLOCK=false
  BLOCK_CONTENT=""

  while IFS= read -r line; do
    if [[ "$line" =~ ^\`\`\`mermaid ]]; then
      IN_BLOCK=true
      BLOCK_CONTENT=""
      continue
    fi
    if $IN_BLOCK && [[ "$line" =~ ^\`\`\` ]]; then
      IN_BLOCK=false
      BLOCK_NUM=$((BLOCK_NUM + 1))
      BLOCK_FILE="$TMPDIR_WORK/block_${BLOCK_NUM}.mmd"
      echo "$BLOCK_CONTENT" > "$BLOCK_FILE"

      OUT_FILE="$TMPDIR_WORK/block_${BLOCK_NUM}.svg"
      if $MMDC -i "$BLOCK_FILE" -o "$OUT_FILE" --quiet 2>/dev/null; then
        echo "  ✓ Diagram $BLOCK_NUM OK"
      else
        echo "  ✗ Diagram $BLOCK_NUM FAILED in $md_file"
        ERRORS=$((ERRORS + 1))
      fi
      continue
    fi
    if $IN_BLOCK; then
      BLOCK_CONTENT="${BLOCK_CONTENT}${line}
"
    fi
  done < "$md_file"

  if [ $BLOCK_NUM -eq 0 ]; then
    echo "  (no mermaid blocks found)"
  fi
done

echo ""
if [ $ERRORS -gt 0 ]; then
  echo "FAILED: $ERRORS diagram(s) did not render."
  exit 1
else
  echo "All Mermaid diagrams validated successfully."
  exit 0
fi
