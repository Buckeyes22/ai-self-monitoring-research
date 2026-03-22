#!/usr/bin/env bash
# adversarial-check.sh — Stop hook
# Lightweight check: are there substantive documents without a frame.md?
# Must be fast — runs after every response

PATTERN="plan\|design\|analysis\|recommendation\|matrix\|spec\|proposal\|audit\|review\|migration"

# Quick scan: any matching .md files in cwd (shallow)?
FOUND=$(find . -maxdepth 2 -name "*.md" -not -path "*/node_modules/*" -not -path "*/.git/*" -not -name "frame.md" 2>/dev/null | head -20 | command grep -il "$PATTERN" 2>/dev/null | head -5)

if [[ -n "$FOUND" ]]; then
  if [[ ! -f "frame.md" && ! -f ".ai/frame.md" ]]; then
    HAS_GAP=0
    while IFS= read -r f; do
      DIR=$(dirname "$f")
      if [[ ! -f "${DIR}/frame.md" && ! -f "${DIR}/.ai/frame.md" ]]; then
        HAS_GAP=1
        break
      fi
    done <<< "$FOUND"
    if [[ "$HAS_GAP" -eq 1 ]]; then
      echo "WARN: Substantive documents exist without a frame document"
    fi
  fi
fi

exit 0
