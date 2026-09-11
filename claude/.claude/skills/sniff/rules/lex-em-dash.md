---
id: lex-em-dash
code: LEX014
name: Em or en dash
family: lexical
applies_to: [core]
severity: warning
fix: manual
evidence: RE
llm_exempt: true
message: Em or en dash; house style bans it. Use a period or comma.
sniffers:
  - kind: vale
    pattern: '[—–]'
    confidence: high
    hook_safe: true
    precision: 1.00   # house-style ban: any occurrence is a violation
    n: 0
---

House style bans the em dash and en dash. Split the clause with a period, or join it with a comma.
Do not swap one dash for the other, and do not use a spaced hyphen as a stand-in.

Bad:  The union is tighter — and more precise.
Good: The union is tighter. It is also more precise.

Not a finding inside a quoted example or code block.
