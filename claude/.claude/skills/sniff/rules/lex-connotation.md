---
id: lex-connotation
code: LEX003
name: Connotation load
family: lexical
applies_to: [core]
severity: warning
fix: manual
evidence: prac
message: A word importing a register the task never asked for.
sniffers:
  - kind: llm
    confidence: medium
    hook_safe: false
---

A word drags in tone the task did not ask for, nudging the output's register.

Bad:  Interrogate the config and brutally trim the output.
Good: Read the config and remove unused output.

Not a finding when the loaded word is the accurate one.
