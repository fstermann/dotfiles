---
id: str-example-contradicts-rule
name: Example contradicts instruction
family: structural
applies_to: [prompt]
severity: warning
fix: manual
evidence: prac
message: A few-shot example that violates a stated rule; the example wins.
sniffers:
  - kind: llm
    confidence: medium
    hook_safe: false
---

An example breaks a rule the prompt states. The example usually wins over the rule.

Bad:  Rule: never use contractions. Example answer: don't do that.
Good: Rule: never use contractions. Example answer: do not do that.

Not a finding when every example obeys the rule.
