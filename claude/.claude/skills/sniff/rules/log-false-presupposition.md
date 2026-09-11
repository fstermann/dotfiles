---
id: log-false-presupposition
code: LOG004
name: False presupposition
family: logical
applies_to: [prompt]
severity: warning
fix: manual
evidence: LLM
message: The instruction presupposes a fact not established; invites confabulation.
sniffers:
  - kind: llm
    confidence: medium
    hook_safe: false
---

The instruction takes an unestablished fact as given, so the model confabulates a reason rather than checking.

Bad:  Explain why the cache lookup fails.
Good: Check whether the cache lookup fails; if it does, explain why.

Not a finding when the presupposed fact is established earlier.
