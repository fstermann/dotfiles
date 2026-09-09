---
id: prag-curse-of-knowledge
name: Assumed context
family: pragmatic
pack: core
severity: warning
fix: manual
evidence: RE
message: The author's unstated background is load-bearing for the task.
sniffers:
  - kind: model
    confidence: medium
    hook_safe: false
---

The task leans on background only the author holds. The reader cannot act on it.

Bad:  Fix it the way we discussed.
Good: Fix the retry logic to back off exponentially.

Not a finding when the shared context is written down.
