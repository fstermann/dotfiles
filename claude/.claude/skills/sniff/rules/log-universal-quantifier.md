---
id: log-universal-quantifier
name: Unenforceable universal
family: logical
applies_to: [core]
severity: warning
fix: manual
evidence: ISO
message: always/never attached to something that cannot be guaranteed. In the spec pack this is an error.
sniffers:
  - kind: llm
    confidence: medium
    hook_safe: false
---

A universal claim bound to something the reader cannot actually guarantee. The model checks enforceability.

Bad:  Always return within 10 ms.
Good: Return within 10 ms for inputs under 1 KB.

Not a finding when the universal is genuinely enforceable or bounded.
