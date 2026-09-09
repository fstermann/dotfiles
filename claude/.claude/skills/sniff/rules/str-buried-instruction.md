---
id: str-buried-instruction
name: Buried instruction
family: structural
pack: prompt
severity: warning
fix: manual
evidence: LLM
message: A critical directive placed mid-document in a long prompt.
sniffers:
  - kind: model
    confidence: medium
    hook_safe: false
---

A must-follow rule sits in the middle of a long prompt, where retrieval is measurably worse than at either end.

Bad:  A long prompt with the only redaction rule stated in the middle of page two.
Good: The redaction rule stated in the opening constraints block.

Not a finding when the prompt is short or the directive sits at either end.
