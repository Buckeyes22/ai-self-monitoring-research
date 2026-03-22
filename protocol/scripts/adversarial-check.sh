#!/usr/bin/env bash
# adversarial-check.sh — Path E Component 3: Post-Response Violation Check
# Hook type: Stop (matcher: "")
#
# Runs after every Claude response. Must be FAST.
# Checks for the highest-signal violation: substantive documents
# existing without a frame document.
#
# This is Option A (inline check). Upgrade to Option B (subagent dispatch)
# once the frame gate is proven.
#
# Exit 0 always — informational warnings only, never blocks

# Quick check: do substantive docs exist without a frame?
HAS_FRAME=0
HAS_SUBSTANTIVE=0
SUBSTANTIVE_FILE=""

# Check for frame documents in common locations
for f in frame.md .ai/frame.md docs/frame.md; do
  if [[ -f "$f" ]]; then
    HAS_FRAME=1
    break
  fi
done

# Only look for substantive docs if no frame exists (fast exit)
if [[ "$HAS_FRAME" -eq 0 ]]; then
  for dir in "." "docs" ".ai"; do
    [[ ! -d "$dir" ]] && continue
    for f in "$dir"/*.md; do
      [[ ! -f "$f" ]] && continue
      BASENAME=$(basename "$f" | tr '[:upper:]' '[:lower:]')
      case "$BASENAME" in
        *plan*|*design*|*analysis*|*recommendation*|*matrix*|\
        *spec*|*proposal*|*audit*|*review*|*migration*|\
        *strategy*|*architecture*|*assessment*)
          HAS_SUBSTANTIVE=1
          SUBSTANTIVE_FILE="$f"
          break 2
          ;;
      esac
    done
  done
fi

if [[ "$HAS_SUBSTANTIVE" -eq 1 && "$HAS_FRAME" -eq 0 ]]; then
  echo "WARN: Substantive document '${SUBSTANTIVE_FILE}' exists without a frame document." >&2
  echo "Path E requires frame.md for auditable, verifiable generation." >&2
fi

exit 0
