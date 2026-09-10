---
id: lex-subjective
name: Subjective language
family: lexical
applies_to: [core]
severity: warning
fix: manual
evidence: ISO
message: Subjective adjective with no shared referent; not verifiable.
sniffers:
  - kind: vale
    pattern: '\b(user-friendly|user friendly|easy to use|easy-to-use|intuitive|seamless|cost-effective|state of the art|state-of-the-art|scalable|flexible|robust|elegant|ergonomic)\b'
    confidence: medium
    hook_safe: false   # 0.76 < 0.90 bar: "flexible" defined-terms, proper nouns, citation titles
    precision: 0.76   # PURE spec corpus, n=29, 2026-09-09
    n: 29
  - kind: llm
    confidence: medium
    hook_safe: false
---

Adjectives that assert quality without a testable referent. Two readers disagree on whether the
output met the bar.

Bad:  Build a user-friendly, robust config loader.
Good: The loader rejects an unknown key with a named error and loads a 1 MB file in under 50 ms.

Not a finding inside a quoted example or code block.
