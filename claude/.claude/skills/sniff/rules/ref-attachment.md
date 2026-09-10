---
id: ref-attachment
name: Attachment ambiguity
family: referential
applies_to: [core]
severity: warning
fix: manual
evidence: RE
message: A modifier attachable to two heads.
sniffers:
  - kind: llm
    confidence: medium
    hook_safe: false
---

A prepositional or relative clause that can attach to two heads, including garden-path readings.

Bad:  Log the request from the client that failed.
Good: Log the request that failed; it came from the client.

Not a finding when only one attachment is grammatically possible.
