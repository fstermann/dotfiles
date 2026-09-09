---
id: log-no-success-criteria
name: No success criteria
family: logical
pack: core
severity: warning
fix: manual
evidence: RE
message: A task with no statement of what a correct output looks like.
sniffers:
  - kind: model
    confidence: medium
    hook_safe: false
---

A task with no definition of done. Any output is arguably compliant.

Bad:  Improve the onboarding docs.
Good: Rewrite the onboarding docs so a new hire can deploy in under 30 minutes.

Not a finding when success is defined elsewhere in scope.
