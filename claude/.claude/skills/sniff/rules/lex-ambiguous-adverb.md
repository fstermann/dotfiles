---
id: lex-ambiguous-adverb
code: LEX001
name: Ambiguous adverb
family: lexical
applies_to: [core]
severity: warning
fix: manual
evidence: ISO
message: Manner adverb with no measurable criterion.
sniffers:
  - kind: vale
    pattern: '\b(quickly|properly|carefully|appropriately|reasonably|efficiently|gracefully|adequately)\b'
    confidence: high
    hook_safe: true
    precision: 1.00   # PURE spec corpus, n=30, 2026-09-09
    n: 30
  - kind: llm
    confidence: medium
    hook_safe: false
---

An adverb that names a quality of execution without a threshold. "Handle errors gracefully" gives
the implementer nothing to check against.

Bad:  Handle a dropped connection gracefully.
Good: On a dropped connection, retry twice with backoff, then surface a `ConnectionError`.

Not a finding inside a quoted example or code block.
