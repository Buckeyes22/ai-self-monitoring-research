# Path E Implementation Plan

## What Gets Built

Three Claude Code hooks that install globally via `~/.claude/settings.json`. They work across all projects without adding cognitive load to the AI's context.

---

## Component 1: Frame Document Gate

**Hook type:** PreToolUse
**Matcher:** Write
**Trigger:** When the AI is about to write a file that matches plan/design/analysis patterns

### Logic

```bash
#!/usr/bin/env bash
# frame-gate.sh — Blocks substantive generation without a frame document

# Read hook input
HOOK_INPUT=$(cat)
FILE_PATH=$(echo "$HOOK_INPUT" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)

# Skip if not a substantive document
[[ -z "$FILE_PATH" ]] && exit 0
[[ ! "$FILE_PATH" =~ (plan|design|analysis|recommendation|matrix|spec|proposal|audit|review) ]] && exit 0
[[ "$FILE_PATH" =~ frame ]] && exit 0  # Don't block frame creation itself

# Check if a frame document exists for this task
FRAME_DIR="$(dirname "$FILE_PATH")"
FRAME_FILE="${FRAME_DIR}/frame.md"

# Also check project root and .ai/
[[ -f "$FRAME_FILE" ]] && exit 0
[[ -f ".ai/frame.md" ]] && exit 0
[[ -f "frame.md" ]] && exit 0

echo "BLOCK: No frame document found for substantive generation."
echo "Before writing '${FILE_PATH}', create a frame.md documenting:"
echo "  - Task (one sentence)"
echo "  - Scope (explicit list of what's covered)"
echo "  - Source material (every file/doc being drawn from)"
echo "  - NOT covering (explicit exclusions with reasoning)"
echo "  - Categories (DO / USE / HOW)"
echo "  - Assumptions (each stated, each marked verified or unverified)"
echo "  - What would a hostile reviewer say is missing?"
echo ""
echo "Write the frame to: ${FRAME_FILE}"
exit 2
```

### What it catches
- SM-012 (260-file migration gap) — the plan would have needed a frame, and the frame's source material check would have shown the framework files weren't covered
- SM-001 (scope contamination) — the frame's "NOT covering" section would have required explicit reasoning about PaddockLink
- SM-002 (false comprehensiveness) — the frame's scope would have listed the 12 engagement shapes, surfacing the mismatch

---

## Component 2: Mechanical Frame Verifier

**Hook type:** PostToolUse
**Matcher:** Write
**Trigger:** When a frame.md is written, verify it before allowing subsequent work

### Logic

```bash
#!/usr/bin/env bash
# frame-verify.sh — Mechanically verify a frame document against reality

HOOK_INPUT=$(cat)
FILE_PATH=$(echo "$HOOK_INPUT" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)

# Only run on frame documents
[[ ! "$FILE_PATH" =~ frame\.md$ ]] && exit 0

FRAME="$FILE_PATH"
GAPS=0

# 1. Verify every file listed in "Source Material" exists
IN_SOURCE=0
while IFS= read -r line; do
  if echo "$line" | command grep -qi "^## Source Material"; then
    IN_SOURCE=1; continue
  fi
  if [[ "$IN_SOURCE" -eq 1 ]] && echo "$line" | command grep -qE "^## "; then
    break
  fi
  if [[ "$IN_SOURCE" -eq 1 ]] && echo "$line" | command grep -qE "^- "; then
    path=$(echo "$line" | sed 's/^- //' | sed 's/ .*//')
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
if ! command grep -qi "NOT Covering\|Not covering\|Exclusions" "$FRAME" 2>/dev/null; then
  echo "WARN: No 'NOT covering' section — every frame must state what's excluded"
  GAPS=$((GAPS + 1))
fi

if [[ "$GAPS" -gt 0 ]]; then
  echo "BLOCK: Frame has $GAPS gap(s). Fix before proceeding with generation."
  exit 2
fi

echo "INFO: Frame verified — $UNVERIFIED unverified assumption(s)"
exit 0
```

### What it catches
- Missing source files (the frame claims to reference files that don't exist)
- Missing categories (the frame doesn't do the DO/USE/HOW check)
- Missing exclusion reasoning (the frame doesn't explain what it's NOT covering)
- Unverified assumptions (flagged for awareness, not blocked)

---

## Component 3: Adversarial Reviewer

**Hook type:** Stop
**Trigger:** After every Claude response, evaluate for guardrail violations

### Logic

This is the most complex component because it needs to dispatch to a separate evaluation. Two implementation options:

**Option A: Inline script check (simpler, less effective)**
```bash
#!/usr/bin/env bash
# adversarial-check.sh — Post-response quick check for common violations

# This runs after every Stop, so it must be FAST
# Only checks for the highest-signal violations

# Check if a frame exists and work is happening without it
if ls *.md .ai/*.md 2>/dev/null | command grep -qiE "plan|design|analysis|recommendation"; then
  if [[ ! -f "frame.md" && ! -f ".ai/frame.md" ]]; then
    echo "WARN: Substantive documents exist without a frame document"
  fi
fi

# Check for common conversation traps in recent output
# (This is limited — it can only check what's been written to files, not conversation)
```

**Option B: Subagent dispatch (more effective, higher cost)**
The Stop hook dispatches the AI's last response to a subagent with a hostile prompt:

```
You are an adversarial reviewer. Your ONLY job is to find what's wrong.
Read the following AI response and check:
1. Did it claim something was "comprehensive" without verification?
2. Did it answer a different question than what was asked?
3. Did it acknowledge a problem then immediately move to solutions?
4. Did it present assumptions as facts?
5. Did it soften a failure with complexity-hiding language?
6. Did it limit solutions based on its model of the user?
Report findings. If none found, say "No violations detected."
```

**Recommendation: Start with Option A, upgrade to Option B once the frame gate is proven.**

---

## Installation

Add to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write",
        "hooks": [{
          "type": "command",
          "command": "bash ~/.claude/scripts/path-e/frame-gate.sh"
        }]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Write",
        "hooks": [{
          "type": "command",
          "command": "bash ~/.claude/scripts/path-e/frame-verify.sh"
        }]
      }
    ],
    "Stop": [
      {
        "matcher": "",
        "hooks": [{
          "type": "command",
          "command": "bash ~/.claude/scripts/path-e/adversarial-check.sh"
        }]
      }
    ]
  }
}
```

Scripts live in `~/.claude/scripts/path-e/` — global, not project-specific.

---

## Testing Plan

1. Install the hooks
2. Start a new session
3. Ask the AI to "create a migration plan for this codebase"
4. Verify: the frame gate blocks until a frame.md is created
5. Create a frame with a deliberate gap (omit a source directory)
6. Verify: the mechanical verifier catches the gap
7. Fix the frame, proceed with generation
8. Verify: the generation proceeds within the verified frame
9. Check: is the output better than it would have been without the frame?

## Success Criteria

Path E is working when:
- The AI cannot generate substantive documents without first externalizing its frame
- Mechanical verification catches source material gaps before generation begins
- The frame document creates an auditable artifact that the user can review
- The AI's cognitive load is REDUCED (fewer self-monitoring instructions needed because the frame handles verification externally)

## What to Measure

Track every session:
- Did the frame gate fire? How many times?
- Did mechanical verification find gaps? What kind?
- Did the adversarial reviewer (if implemented) catch violations?
- Were there self-monitoring failures that Path E missed? (Add to dataset)
- Is the AI's overall output quality better, worse, or same compared to instruction-only sessions?
