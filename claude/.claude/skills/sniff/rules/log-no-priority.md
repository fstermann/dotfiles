---
id: log-no-priority
name: Unstated priority
family: logical
applies_to: [core]
severity: warning
fix: manual
evidence: LLM
message: Two constraints that can conflict at runtime with no tie-breaker.
sniffers:
  - kind: llm
    confidence: medium
    hook_safe: false
---

Two constraints that will sometimes collide, with nothing saying which wins.

Bad:  Be thorough and finish within one paragraph.
Good: Finish within one paragraph; drop detail before length.

Not a finding when the constraints cannot conflict.
