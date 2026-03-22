#!/usr/bin/env bash
# frame-verify.sh — PostToolUse hook on Write
# Mechanically verifies frame.md against reality after it's written

HOOK_INPUT=$(cat)
FILE_PATH=$(echo "$HOOK_INPUT" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)

# Only run on frame documents
[[ ! "$FILE_PATH" =~ frame\.md$ ]] && exit 0
[[ ! -f "$FILE_PATH" ]] && exit 0

FRAME="$FILE_PATH"
GAPS=0
UNVERIFIED=0

# 1. Verify every path listed in "Source Material" exists
IN_SOURCE=0
while IFS= read -r line; do
  if echo "$line" | command grep -qi "^##.*[Ss]ource [Mm]aterial"; then
    IN_SOURCE=1; continue
  fi
  if [[ "$IN_SOURCE" -eq 1 ]] && echo "$line" | command grep -qE "^## "; then
    break
  fi
  if [[ "$IN_SOURCE" -eq 1 ]] && echo "$line" | command grep -qE "^- "; then
    # Extract path — strip leading "- ", strip trailing description
    path=$(echo "$line" | sed 's/^- *//' | sed 's/ *(.*//' | sed 's/ *—.*//' | sed 's/[[:space:]]*$//')
    # Skip lines that are clearly not file paths
    [[ "$path" =~ ^[A-Z] ]] && continue
    [[ "$path" == "None" || "$path" == "N/A" ]] && continue
    if [[ ! -f "$path" && ! -d "$path" ]]; then
      echo "WARN: Source material not found: $path"
      GAPS=$((GAPS + 1))
    fi
  fi
done < "$FRAME"

# 2. Check DO/USE/HOW sections have content
for section in "What does this need to DO" "What does this need to USE" "HOW should each part"; do
  if ! command grep -qi "$section" "$FRAME" 2>/dev/null; then
    echo "WARN: Missing category check: $section"
    GAPS=$((GAPS + 1))
  fi
done

# 3. Check for unverified assumptions
UNVERIFIED=$(command grep -ci "unverified\|asserting\|not verified" "$FRAME" 2>/dev/null || echo 0)
if [[ "$UNVERIFIED" -gt 0 ]]; then
  echo "INFO: Frame contains $UNVERIFIED unverified assumption(s) — verify or surface to user"
fi

# 4. Check "NOT covering" section exists and has content
if ! command grep -qi "NOT [Cc]overing\|Not covering\|Exclusions" "$FRAME" 2>/dev/null; then
  echo "WARN: No 'NOT covering' section — every frame must state what's excluded"
  GAPS=$((GAPS + 1))
fi

if [[ "$GAPS" -gt 0 ]]; then
  echo "BLOCK: Frame has $GAPS gap(s). Fix before proceeding with generation."
  exit 2
fi

echo "Frame verified — $UNVERIFIED unverified assumption(s)"
exit 0
