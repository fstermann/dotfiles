---
id: prag-register-mismatch
name: Register mismatch
family: pragmatic
pack: core
severity: warning
fix: manual
evidence: prac
message: An instruction register implying an output register nobody asked for.
sniffers:
  - kind: model
    confidence: medium
    hook_safe: false
---

The instruction's tone implies an output tone the author did not request.

Bad:  Casually, produce the formal compliance report.
Good: Produce the formal compliance report.

Not a finding when the register matches the output.
