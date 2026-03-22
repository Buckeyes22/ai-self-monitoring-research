#!/usr/bin/env bash
# frame-verify.sh — Path E Component 2: Mechanical Frame Verifier
# Hook type: PostToolUse (matcher: Write)
#
# After a frame.md is written, mechanically verify it against reality:
# - Do all listed source files actually exist?
# - Are DO/USE/HOW categories present?
# - Is there a NOT Covering section?
# - Are there unverified assumptions?
#
# Exit 0 = frame verified (proceed with generation)
# Exit 2 = frame has gaps (fix before proceeding)

HOOK_INPUT=$(cat)

# Extract file_path
FILE_PATH=$(echo "$HOOK_INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
if [[ -z "$FILE_PATH" ]]; then
  FILE_PATH=$(echo "$HOOK_INPUT" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
fi

# Only run on frame documents
[[ ! "$FILE_PATH" =~ frame\.md$ ]] && exit 0
[[ ! -f "$FILE_PATH" ]] && exit 0

FRAME="$FILE_PATH"
GAPS=0
WARNINGS=""

# Helper: accumulate warnings (all go to stderr for hook visibility)
warn() {
  WARNINGS="${WARNINGS}WARN: $1\n"
  GAPS=$((GAPS + 1))
}

# ── Check 1: Verify every path listed under "Source Material" exists ──
IN_SOURCE=0
SOURCE_COUNT=0
while IFS= read -r line; do
  # Detect section start
  if echo "$line" | command grep -qi "^## Source Material\|^## Source"; then
    IN_SOURCE=1
    continue
  fi
  # Detect next section (end of source material)
  if [[ "$IN_SOURCE" -eq 1 ]] && echo "$line" | command grep -qE "^## "; then
    break
  fi
  # Check each listed path
  if [[ "$IN_SOURCE" -eq 1 ]] && echo "$line" | command grep -qE "^- "; then
    # Extract path: strip "- ", backticks, trailing descriptions
    path=$(echo "$line" | sed 's/^- //' | sed 's/`//g' | sed 's/ — .*//' | sed 's/ (.*//' | sed 's/[[:space:]]*$//')
    if [[ -n "$path" && "$path" != "None" && "$path" != "N/A" ]]; then
      SOURCE_COUNT=$((SOURCE_COUNT + 1))
      if [[ ! -f "$path" && ! -d "$path" ]]; then
        warn "Source material not found: $path"
      fi
    fi
  fi
done < "$FRAME"

if [[ "$SOURCE_COUNT" -eq 0 ]]; then
  warn "No source material paths listed in frame"
fi

# ── Check 2: DO / USE / HOW categories present ──
for section in "What does this need to DO" "What does this need to USE" "HOW should each part"; do
  if ! command grep -qi "$section" "$FRAME" 2>/dev/null; then
    warn "Missing category: '$section'"
  fi
done

# ── Check 3: NOT Covering section exists ──
if ! command grep -qiE "NOT Covering|Not covering|Exclusions|Out of Scope" "$FRAME" 2>/dev/null; then
  warn "No 'NOT Covering' section — every frame must state what's excluded"
fi

# ── Check 4: Unverified assumptions (informational, not blocking) ──
UNVERIFIED=$(command grep -ci "unverified\|asserting\|not verified\|assumed but" "$FRAME" 2>/dev/null || echo "0")

# ── Check 5: Hostile review section exists ──
if ! command grep -qiE "Hostile Reviewer|hostile review|What.* missing" "$FRAME" 2>/dev/null; then
  warn "No 'Hostile Reviewer' section — frame should include adversarial self-review"
fi

# ── Result ──
if [[ "$GAPS" -gt 0 ]]; then
  {
    echo -e "$WARNINGS"
    echo "BLOCK: Frame has $GAPS gap(s). Fix before proceeding with generation."
  } >&2
  exit 2
fi

if [[ "$UNVERIFIED" -gt 0 ]]; then
  echo "Frame verified with $UNVERIFIED unverified assumption(s) — verify or surface to user before proceeding." >&2
else
  echo "Frame verified — all checks passed." >&2
fi
exit 0
