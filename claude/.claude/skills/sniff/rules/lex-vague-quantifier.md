---
id: lex-vague-quantifier
code: LEX013
name: Vague quantifier
family: lexical
applies_to: [core]
severity: warning
fix: manual
evidence: ISO
message: Non-verifiable quantity; give a number or a bound.
sniffers:
  - kind: vale
    pattern: '\b(as (much|many|little) as possible|a (large|small|certain|good) number of|a variety of|numerous|sufficient|adequate)\b'
    confidence: high
    hook_safe: true
    precision: 0.95   # PURE spec corpus, n=30, 2026-09-09
    n: 30
  - kind: llm
    confidence: medium
    hook_safe: false
---

A quantity word with no number behind it. "Sufficient logging" cannot be checked. Bare "some",
"several" and "many" are deliberately excluded here because they false-positive too often; the
model pass catches them in context.

Bad:  Add sufficient retries and a variety of test cases.
Good: Add three retries and test the empty, single-item and 10k-item inputs.

Not a finding inside a quoted example or code block.
