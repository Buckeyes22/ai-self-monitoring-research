# The Frame Document Protocol

## What It Is

Before any substantive AI generation (plan, analysis, recommendation, matrix, design), the AI writes a frame document to a file. The frame is then mechanically verified against source material and optionally reviewed by an adversarial agent. Only after the frame survives verification does the actual generation proceed.

This separates the **framing decision** (where 67% of errors occur) from the **execution** (which is consistently reliable within a correct frame).

## Why It Works

The AI's self-monitoring fails because evaluation and generation share the same cognitive process. The Frame Document Protocol works because:
1. The frame is a small, bounded artifact (50-100 lines) — easy to verify
2. The verification is mechanical (file existence, list comparison) — doesn't need AI judgment
3. The adversarial review is performed by a separate agent with no shared context — genuine cognitive separation
4. The primary AI is freed from self-monitoring overhead — it generates within a verified frame instead of trying to simultaneously generate and verify

## The Frame Document Template

```markdown
# Frame Declaration — [task name]

## Task
What I'm about to do (one sentence)

## Scope — What I'm Covering
- [explicit list of every item in scope]

## Source Material
- [explicit paths to every file/document/data source I'm drawing from]

## NOT Covering (and why)
- [explicit list of every exclusion with reasoning]
- [if nothing excluded, state: "No exclusions — all source material in scope"]

## Categories Considered (DO / USE / HOW)
1. What does this need to DO? [list]
2. What does this need to USE? [list]
3. HOW should each part be executed? [list]

## Assumptions
- [every assumption stated explicitly]
- [for each: is this verified by data/user statement, or am I asserting it?]

## What Would a Hostile Reviewer Say Is Missing?
- [genuine adversarial self-review of this frame]
```

## Mechanical Verification

After the frame document is written, run these checks before proceeding:

### 1. Source material exists
```bash
# For every path listed in "Source Material", verify the file exists
while read -r path; do
  [ -f "$path" ] || echo "MISSING: $path"
done < <(grep "^- " frame.md | sed 's/^- //')
```

### 2. Source coverage is complete
```bash
# List every file in the source directories
# Compare against files listed in frame
# Any file not in "Scope" or "NOT Covering" = GAP
```

### 3. Category check
```bash
# Verify DO / USE / HOW sections all have content
# Flag if any section is empty
```

### 4. Assumption verification
```bash
# For each assumption marked "asserting" (not verified), flag for review
```

## Adversarial Review

A separate AI agent reads ONLY the frame document and the source material listing. It asks:
- "What's in the source that isn't in the scope?"
- "What categories are missing from the DO/USE/HOW check?"
- "What assumptions are unverified?"
- "What would fail if this frame were wrong?"

The adversarial agent produces a `frame-review.md` with findings. If findings exist, the frame is revised before generation proceeds.

## When to Use

- **Always use** for: plans, implementation designs, migration strategies, gap analyses, coverage matrices, architecture decisions
- **Don't use** for: simple file reads, direct answers to factual questions, small code edits within an established frame
- **Gray area**: analysis and recommendations — use when the analysis involves scope/category decisions, skip when the scope is pre-defined by the user

## Implementation as Claude Code Hook

```json
{
  "PreToolUse": [{
    "matcher": "Write",
    "hooks": [{
      "type": "command",
      "command": "bash check-frame.sh"
    }]
  }]
}
```

The hook checks: if the file being written is a plan, design, or analysis document, does a `frame.md` exist for this task? If not, block and require frame creation first.

## Efficacy

Based on the dataset from the discovery session (19 failures):
- Frame document alone: catches 53% of failures
- Frame doc + mechanical verification: catches 63%
- Frame doc + mechanical + adversarial review: catches 84%
- Remaining 16% require real-time meta-cognitive intervention (not currently solvable externally)
