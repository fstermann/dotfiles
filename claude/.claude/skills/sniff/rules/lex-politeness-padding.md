---
id: lex-politeness-padding
code: LEX008
name: Politeness padding
family: lexical
applies_to: [core]
severity: suggestion
fix: auto
evidence: prac
message: Filler politeness adds tokens and no constraint.
sniffers:
  - kind: vale
    pattern: "\\b(I'?d (really )?appreciate|if you could,? please|would you mind|I was wondering if|it would be great if|if it'?s not too much trouble|please kindly)\\b"
    confidence: high
    hook_safe: false
  - kind: llm
    confidence: medium
    hook_safe: false
---

Softeners aimed at a model carry no instruction and cost tokens. Drop them; state the task.

Bad:  I was wondering if you could please validate the token.
Good: Validate the token.

Not a finding inside a quoted example or code block.
