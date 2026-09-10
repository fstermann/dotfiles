---
id: lex-comparative
name: Comparative without baseline
family: lexical
applies_to: [core]
severity: warning
fix: manual
evidence: ISO
message: Comparative with no stated reference point.
sniffers:
  - kind: vale
    pattern: '\b(faster|slower|better|worse|cheaper|easier|harder|quicker|lighter|simpler|stronger|smaller|larger|bigger)\b'
    confidence: low
    hook_safe: false
  - kind: llm
    confidence: medium
    hook_safe: false
---

A comparative names a direction but no baseline, so nothing says how much or than what. The pattern is a trigger; the model checks whether a reference point is given.

Bad:  Make the parser faster.
Good: Make the parser run in under 100 ms.

Not a finding when a baseline follows ("faster than the current 200 ms") or inside a quoted example.
