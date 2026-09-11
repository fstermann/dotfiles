---
id: lex-loophole
code: LEX005
name: Loophole or escape clause
family: lexical
applies_to: [core]
severity: warning
fix: manual
evidence: ISO
message: Optional-clause phrase makes the requirement skippable without saying who decides.
sniffers:
  - kind: vale
    pattern: '\b(if possible|where applicable|as appropriate|as needed|if necessary|when feasible)\b'
    confidence: high
    hook_safe: false   # precision qualifies but n=19 < 25; recheck on a larger corpus
    precision: 0.95   # PURE spec corpus, n=19, 2026-09-09
    n: 19
  - kind: llm
    confidence: medium
    hook_safe: false
---

Phrases that make a requirement optional without saying who decides or on what condition. The
reader is licensed to skip the work, and the author keeps deniability that it was ever required.

Bad:  Validate the payload where applicable.
Good: Validate the payload when it contains a `customer_id`.

Not a finding when the deciding condition is stated in the same sentence (e.g. "if the file
exists, delete it"), or when the phrase appears inside a quoted example or code block.
