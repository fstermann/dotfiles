---
id: ref-passive-actor
name: Actor-eliding passive
family: referential
applies_to: [core]
severity: warning
fix: manual
evidence: RE
message: Passive voice that drops the actor.
sniffers:
  - kind: llm
    confidence: medium
    hook_safe: false
---

Passive that omits who acts. Passive alone is fine; passive with no agent leaves the doer unspecified. The model confirms the actor is missing.

Bad:  The output should be validated.
Good: The CI job validates the output.

Not a finding when the actor is named ("validated by the gateway") or obvious in context.
