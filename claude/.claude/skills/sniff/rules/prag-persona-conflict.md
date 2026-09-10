---
id: prag-persona-conflict
name: Persona conflicts with task
family: pragmatic
applies_to: [core]
severity: warning
fix: manual
evidence: prac
message: An assigned persona that conflicts with the task.
sniffers:
  - kind: llm
    confidence: medium
    hook_safe: false
---

The assigned persona pulls against what the task needs.

Bad:  You are terse. Now write a full tutorial with worked examples.
Good: Write a full tutorial with worked examples.

Not a finding when persona and task agree.
