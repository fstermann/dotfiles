---
id: ref-incomplete
name: Incomplete reference
family: referential
pack: core
severity: warning
fix: manual
evidence: RE
message: A reference with no resolvable target.
sniffers:
  - kind: deterministic
    pattern: '\b(the (section|table|figure|file|diagram|list|steps?) (above|below)|as (previously|described above|mentioned above)|see (above|below)|the attached|the aforementioned)\b'
    confidence: medium
    hook_safe: false
  - kind: model
    confidence: medium
    hook_safe: false
---

A pointer to something the reader cannot resolve. The pattern triggers; the model checks whether the target is actually findable.

Bad:  Follow the steps in the section above.
Good: Follow the steps in section 3.2 of this file.

Not a finding when the target is numbered or named unambiguously.
