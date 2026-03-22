#!/usr/bin/env bash
# frame-gate.sh — PreToolUse hook on Write
# Blocks creation of substantive documents without a frame.md

HOOK_INPUT=$(cat)
FILE_PATH=$(echo "$HOOK_INPUT" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)

# Skip if no file path extracted
[[ -z "$FILE_PATH" ]] && exit 0

# Get just the filename for pattern matching
BASENAME=$(basename "$FILE_PATH")

# Don't block frame.md creation itself
[[ "$BASENAME" =~ frame ]] && exit 0

# Only gate substantive document patterns
[[ ! "$BASENAME" =~ (plan|design|analysis|recommendation|matrix|spec|proposal|audit|review|migration) ]] && exit 0

# Check if a frame document exists
FRAME_DIR="$(dirname "$FILE_PATH")"

# Check same directory
[[ -f "${FRAME_DIR}/frame.md" ]] && exit 0
# Check .ai/ subdirectory
[[ -f "${FRAME_DIR}/.ai/frame.md" ]] && exit 0
# Check project root (cwd)
[[ -f "frame.md" ]] && exit 0
[[ -f ".ai/frame.md" ]] && exit 0

echo "BLOCK: No frame document found for substantive generation."
echo "Before writing '$(basename "$FILE_PATH")', create a frame.md documenting:"
echo "  - Task (one sentence)"
echo "  - Scope (explicit list of what's covered)"
echo "  - Source material (every file/doc being drawn from)"
echo "  - NOT covering (explicit exclusions with reasoning)"
echo "  - Categories (DO / USE / HOW)"
echo "  - Assumptions (each stated, each marked verified or unverified)"
echo "  - What would a hostile reviewer say is missing?"
echo ""
echo "Write the frame to: ${FRAME_DIR}/frame.md"
exit 2
