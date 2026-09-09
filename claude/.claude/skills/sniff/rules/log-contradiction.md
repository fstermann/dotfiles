---
id: log-contradiction
name: Contradictory constraints
family: logical
pack: core
severity: warning
fix: manual
evidence: LLM
message: Two constraints in one instruction that cannot both hold.
sniffers:
  - kind: model
    confidence: medium
    hook_safe: false
---

Two constraints in the same instruction that cannot both hold ("detailed but concise", "casual but
formal", "exhaustive list, keep it short"). Models rarely flag the conflict or ask which to
prioritise; they silently blend the two and satisfy neither.

No reliable surface signal, so this is model-only. "but", "however" and "yet" often join the two
halves, but most uses of those words are not contradictions, so they are not a usable trigger.

Bad:  Write a detailed but concise summary covering every edge case in two sentences.
Good: Write a summary of at most three sentences; name the two highest-impact edge cases.

Not a finding when the two constraints apply to different scopes (e.g. "verbose logs, terse UI
copy"), or when one clause resolves the other (a stated tie-breaker).
