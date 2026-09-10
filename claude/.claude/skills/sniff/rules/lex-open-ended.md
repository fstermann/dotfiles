---
id: lex-open-ended
name: Open-ended enumeration
family: lexical
applies_to: [core]
severity: warning
fix: manual
evidence: ISO
message: Open-ended list leaves the tail of the enumeration undefined.
sniffers:
  - kind: vale
    pattern: '(\betc\b|\band so on\b|\band so forth\b|\bamong others\b|\bamong other things\b)'
    confidence: high
    hook_safe: true
    precision: 1.00   # PURE spec corpus, n=30, 2026-09-09
    n: 30
  - kind: llm
    confidence: medium
    hook_safe: false
---

"etc." in a spec hands the reader the job of completing the list, and two readers complete it
differently.

Bad:  Sanitize the input: strip tags, escape quotes, etc.
Good: Sanitize the input: strip tags, escape quotes, and reject bytes above 0x7F.

Not a finding inside a quoted example or code block.
