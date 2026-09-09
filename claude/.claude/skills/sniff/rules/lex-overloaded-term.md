---
id: lex-overloaded-term
name: Overloaded term
family: lexical
pack: core
severity: warning
fix: manual
evidence: RE
message: One term standing for two distinct concepts.
sniffers:
  - kind: model
    confidence: medium
    hook_safe: false
---

One word carrying two meanings in the same document. The reader cannot tell which is meant.

Bad:  Load the context from disk, then append the conversation to the context.
Good: Load the config from disk, then append the message to the history.

Not a finding when both uses share a single meaning.
