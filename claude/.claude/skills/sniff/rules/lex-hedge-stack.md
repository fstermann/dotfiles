---
id: lex-hedge-stack
name: Hedging stack
family: lexical
pack: core
severity: warning
fix: auto
evidence: prac
message: Stacked hedges signal optionality you probably did not intend.
sniffers:
  - kind: deterministic
    pattern: '\b(could|can|may|might|would)[[:space:]]+(potentially|possibly|perhaps|probably|maybe)\b|\b(potentially|possibly|perhaps|probably|maybe)[[:space:]]+(potentially|possibly|perhaps|probably|maybe)\b'
    confidence: high
    hook_safe: false
---

Two or more hedges in a row ("could potentially possibly") weaken an instruction to the point the
reader treats it as optional. Collapse to one modal or none.

Bad:  You could possibly want to validate the token.
Good: Validate the token.

Not a finding inside a quoted example or code block.
