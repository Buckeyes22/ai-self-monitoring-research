#!/usr/bin/env bash
# frame-gate.sh — Path E Component 1: Frame Document Gate
# Hook type: PreToolUse (matcher: Write)
#
# Blocks substantive document generation (plans, designs, analyses, etc.)
# unless a frame.md exists. Forces the AI to externalize framing decisions
# before generation — where 67% of errors occur.
#
# Exit 0 = allow the write
# Exit 2 = block the write (output shown as reason)

HOOK_INPUT=$(cat)

# Extract file_path — jq primary, sed fallback
FILE_PATH=$(echo "$HOOK_INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
if [[ -z "$FILE_PATH" ]]; then
  FILE_PATH=$(echo "$HOOK_INPUT" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
fi

# No file path = nothing to check
[[ -z "$FILE_PATH" ]] && exit 0

# Don't block frame document creation itself
[[ "$FILE_PATH" =~ frame\.md$ ]] && exit 0
[[ "$FILE_PATH" =~ frame-review\.md$ ]] && exit 0

# Only gate substantive document patterns
BASENAME=$(basename "$FILE_PATH" | tr '[:upper:]' '[:lower:]')
case "$BASENAME" in
  *plan*|*design*|*analysis*|*recommendation*|*matrix*|\
  *spec*|*proposal*|*audit*|*review*|*migration*|\
  *strategy*|*architecture*|*assessment*)
    ;; # Falls through to frame check
  *)
    exit 0  # Not a substantive doc — allow
    ;;
esac

# Check for frame.md in multiple locations
FRAME_DIR="$(dirname "$FILE_PATH")"

for candidate in \
  "${FRAME_DIR}/frame.md" \
  "frame.md" \
  ".ai/frame.md" \
  "docs/frame.md"; do
  [[ -f "$candidate" ]] && exit 0
done

# Also check git root (if in a repo and not already checked)
GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || true)
if [[ -n "$GIT_ROOT" ]]; then
  [[ -f "${GIT_ROOT}/frame.md" ]] && exit 0
  [[ -f "${GIT_ROOT}/.ai/frame.md" ]] && exit 0
  [[ -f "${GIT_ROOT}/docs/frame.md" ]] && exit 0
fi

# === BLOCK (write to stderr — Claude Code shows stderr as block reason) ===
{
  echo "BLOCK: No frame document found for substantive generation."
  echo ""
  echo "Path E requires a frame.md BEFORE writing '$(basename "$FILE_PATH")'."
  echo "This separates framing decisions (where errors occur) from execution."
  echo ""
  echo "Create a frame.md documenting:"
  echo "  1. Task — what you're about to do (one sentence)"
  echo "  2. Scope — explicit list of what's covered"
  echo "  3. Source Material — every file/doc being drawn from"
  echo "  4. NOT Covering — explicit exclusions with reasoning"
  echo "  5. Categories — DO / USE / HOW"
  echo "  6. Assumptions — each stated, each marked verified or unverified"
  echo "  7. Hostile Review — what would a hostile reviewer say is missing?"
  echo ""
  echo "Write the frame to: ${FRAME_DIR}/frame.md"
} >&2
exit 2
