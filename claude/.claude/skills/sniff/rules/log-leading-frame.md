---
id: log-leading-frame
name: Leading framing
family: logical
pack: prompt
severity: warning
fix: manual
evidence: LLM
message: Framing that pushes agreement over assessment.
sniffers:
  - kind: deterministic
    pattern: '\b(confirm that|you.?ll agree|as we all know|as we know|obviously|of course,|as you can see|clearly,)\b'
    confidence: medium
    hook_safe: false
  - kind: model
    confidence: medium
    hook_safe: false
---

Wording that asks the reader to agree rather than assess. The model checks whether the frame presumes the answer.

Bad:  Confirm that this design is correct.
Good: Assess whether this design is correct.

Not a finding when the framing is neutral.
