---
id: lex-undefined-jargon
name: Undefined jargon
family: lexical
applies_to: [core]
severity: warning
fix: arg
evidence: ISO
message: A domain term or acronym used before it is expanded.
sniffers:
  - kind: llm
    confidence: medium
    hook_safe: false
---

An acronym or domain term used with no first-use expansion. A reader outside the domain is stuck.

Bad:  Set the MTU before the NIC initialises.
Good: Set the maximum transmission unit (MTU) before the network card initialises.

Not a finding when the term is expanded on first use or is universally known.
