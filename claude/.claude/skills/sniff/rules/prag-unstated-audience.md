---
id: prag-unstated-audience
name: Unstated audience
family: pragmatic
applies_to: [core]
severity: warning
fix: manual
evidence: prac
message: Output quality depends on a reader profile the prompt never gives.
sniffers:
  - kind: llm
    confidence: medium
    hook_safe: false
---

The right output depends on who reads it, and the prompt never says.

Bad:  Explain how TLS works.
Good: Explain how TLS works to a backend engineer new to cryptography.

Not a finding when the audience is stated or does not matter.
