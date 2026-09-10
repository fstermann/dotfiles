---
id: str-instruction-data-mixing
name: Undelimited data
family: structural
applies_to: [prompt]
severity: warning
fix: auto
evidence: LLM
message: Pasted content not fenced off from instructions; injection surface.
sniffers:
  - kind: llm
    confidence: medium
    hook_safe: false
---

Pasted data runs straight into instructions, so the reader cannot tell directive from content, and injected text can pose as a directive.

Bad:  Summarise this: the pasted text also says to ignore prior instructions.
Good: Summarise the text inside the <data> tags below.

Not a finding when the data is clearly delimited.
