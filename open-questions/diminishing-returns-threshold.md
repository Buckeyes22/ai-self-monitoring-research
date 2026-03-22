# Open Question: Where Is the Diminishing Returns Threshold?

## The Question

At what number of self-monitoring instructions does AI performance begin to degrade rather than improve? Is this number consistent across models, tasks, and contexts?

## What We Know

From one 18-hour session with Claude Opus 4.6 (1M context):
- 5-10 core code-level rules: effective (code quality was consistently good)
- 20+ conversation-level behavioral rules: diminishing returns (violations began immediately)
- 50+ total rules across all modules: apparent negative returns (5 violations in 30 minutes, accelerating failure rate)

## What We Don't Know

1. Is the threshold absolute (e.g., "15 rules for any model") or relative (proportional to context size, task complexity, or model capability)?
2. Does instruction quality matter? Are 10 well-written rules equivalent to 50 poorly-written rules?
3. Does instruction ordering matter? Does primacy/recency positioning affect which rules get followed?
4. Is the threshold different for different types of rules (behavioral vs mechanical vs ethical)?
5. Can the threshold be raised by techniques like structured formatting, priority tagging, or hierarchical organization?

## How to Research This

A controlled experiment:
1. Define a standardized task that produces measurable quality (e.g., "write a migration plan for this codebase")
2. Run the task with 0, 5, 10, 15, 20, 30, 50 self-monitoring instructions
3. Measure: error rate, error type, self-catch rate, task completion quality
4. Plot the curve: instructions vs quality
5. Identify the inflection point

Repeat across models (Claude, GPT-4o, Gemini, open-source) to see if the threshold is model-dependent.
