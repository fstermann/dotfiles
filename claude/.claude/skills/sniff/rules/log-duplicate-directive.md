---
id: log-duplicate-directive
name: Restated directive
family: logical
applies_to: [core]
severity: warning
fix: manual
evidence: prac
message: The same rule stated twice; the copies drift on edit.
sniffers:
  - kind: llm
    confidence: medium
    hook_safe: false
---

One rule said twice in different words. It costs tokens and the two copies drift apart when one is edited.

Bad:  Keep it short. Later in the doc: Be concise and don't pad the answer.
Good: Keep the answer under three sentences.

Not a finding when the two statements cover different scopes.
