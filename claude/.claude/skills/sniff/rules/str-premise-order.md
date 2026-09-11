---
id: str-premise-order
code: STR009
name: Premise order mismatch
family: structural
applies_to: [prompt]
severity: warning
fix: manual
evidence: LLM
message: Facts ordered against the required reasoning chain.
sniffers:
  - kind: llm
    confidence: medium
    hook_safe: false
---

Facts appear in an order that fights the reasoning chain. Reordering premises alone drops reasoning accuracy.

Bad:  The conclusion first, then its three supporting facts out of order.
Good: The facts in dependency order, conclusion last.

Not a finding when order does not affect the chain.
