---
id: str-example-recency
name: Few-shot label ordering
family: structural
pack: prompt
severity: warning
fix: auto
evidence: LLM
message: Examples ordered so the last label dominates.
sniffers:
  - kind: model
    confidence: medium
    hook_safe: false
---

Predictions skew toward the label seen near the end of the prompt.

Bad:  Examples ordered pos, pos, neg, neg, neg with all negatives last.
Good: Examples with interleaved or shuffled labels.

Not a finding when order carries meaning.
