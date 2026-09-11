---
id: str-irrelevant-context
code: STR008
name: Irrelevant context
family: structural
applies_to: [prompt]
severity: warning
fix: manual
evidence: LLM
message: Background that does not bear on the task; distracts the model.
sniffers:
  - kind: llm
    confidence: medium
    hook_safe: false
---

Background with no effect on the task. Models are measurably distracted by irrelevant context.

Bad:  Our company was founded in 1998. Parse this date string.
Good: Parse this date string: 2026-09-09.

Not a finding when the context constrains the task.
