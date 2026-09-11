---
id: ref-scope-ambiguity
code: REF005
name: Coordination scope ambiguity
family: referential
applies_to: [core]
severity: warning
fix: manual
evidence: RE
message: Modifier attachment across and/or is undecidable.
sniffers:
  - kind: vale
    pattern: '\b(and|or) [a-z]+ (and|or) [a-z]+\b'
    confidence: medium
    hook_safe: false
  - kind: llm
    confidence: medium
    hook_safe: false
---

A chain of and/or where a modifier could bind to one term or all of them. The model checks whether the grouping is actually ambiguous.

Bad:  Delete files that are old and unused or temporary.
Good: Delete files older than 30 days.

Not a finding when parentheses or wording fix the grouping.
