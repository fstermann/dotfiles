---
id: lex-superlative
name: Superlative
family: lexical
applies_to: [core]
severity: warning
fix: manual
evidence: ISO
message: Superlative sets an unbounded, unreachable target.
sniffers:
  - kind: vale
    pattern: '\b(optimal|ideal|fastest|cleanest|simplest|smartest|strongest|world-class|top-notch|best-in-class)\b'
    confidence: medium
    hook_safe: false
  - kind: llm
    confidence: medium
    hook_safe: false
---

A superlative names a target with no ceiling, so nothing counts as done. "The" + best is excluded
because "best practice" is idiom; the model pass judges bare "best".

Bad:  Choose the optimal data structure for the fastest lookup.
Good: Use a structure with O(1) average lookup; a hash map is fine.

Not a finding inside a quoted example or code block.
