---
id: log-negation-only
name: Negation without positive target
family: logical
pack: core
severity: warning
fix: manual
evidence: LLM
message: A prohibition that names no goal and keeps the banned content in context.
sniffers:
  - kind: model
    confidence: medium
    hook_safe: false
---

A negative instruction names what not to do but not what to do, and the prohibited content stays in context. Larger models do worse on negated prompts. The model checks for a positive target.

Bad:  Don't be verbose.
Good: Keep replies to three sentences.

Not a finding when a positive instruction accompanies the prohibition.
