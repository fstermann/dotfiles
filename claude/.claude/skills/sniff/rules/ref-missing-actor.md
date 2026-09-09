---
id: ref-missing-actor
name: Missing trigger or actor
family: referential
pack: core
severity: warning
fix: manual
evidence: RE
message: An instruction with no stated agent or trigger. In the spec pack this is an error.
sniffers:
  - kind: model
    confidence: medium
    hook_safe: false
---

A requirement with no agent, no condition, or neither. EARS templates exist to force both.

Bad:  The cache is cleared on startup.
Good: The boot script clears the cache on startup.

Not a finding when the actor and trigger are unambiguous in the surrounding section.
