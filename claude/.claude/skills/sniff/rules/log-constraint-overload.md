---
id: log-constraint-overload
name: Constraint overload
family: logical
applies_to: [prompt]
severity: warning
fix: manual
evidence: LLM
message: So many simultaneous constraints that the all-satisfied rate collapses.
sniffers:
  - kind: llm
    confidence: medium
    hook_safe: false
---

Per-constraint accuracy holds while the all-constraints-satisfied rate falls as the count rises. Count the independent constraints in one instruction.

Bad:  Reply in JSON, under 50 words, in French, no numerals, cite two sources, and rhyme.
Good: Reply in JSON with a summary field under 50 words.

Not a finding when the constraints are few or independent.
