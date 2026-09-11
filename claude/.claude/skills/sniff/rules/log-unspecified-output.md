---
id: log-unspecified-output
code: LOG011
name: Unspecified output contract
family: logical
applies_to: [core]
severity: warning
fix: manual
evidence: prac
message: No format, schema or length contract where a consumer expects one.
sniffers:
  - kind: llm
    confidence: medium
    hook_safe: false
---

No format, schema, or length given where downstream code will parse the output.

Bad:  Return the parsed users.
Good: Return a JSON array of {id, email} objects.

Not a finding when no consumer needs a fixed shape.
