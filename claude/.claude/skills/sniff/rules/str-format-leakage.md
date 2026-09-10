---
id: str-format-leakage
name: Format leakage
family: structural
applies_to: [prompt]
severity: warning
fix: manual
evidence: prac
message: Incidental style in examples inferred as a rule.
sniffers:
  - kind: llm
    confidence: medium
    hook_safe: false
---

Incidental style in examples (length, punctuation, hedging) gets read as a requirement.

Bad:  Every example answer is one word, though length is not part of the task.
Good: Examples vary in length so no length rule is implied.

Not a finding when the shared style is the intended contract.
