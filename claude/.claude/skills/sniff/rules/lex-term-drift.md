---
id: lex-term-drift
name: Terminology drift
family: lexical
applies_to: [core]
severity: warning
fix: arg
evidence: RE
message: Several terms used for one concept; the reader infers a distinction that isn't there.
sniffers:
  - kind: llm
    confidence: medium
    hook_safe: false
---

Several words for one concept. The reader applies the principle of contrast and assumes a difference that was never meant.

Bad:  Send the user's token, fetch the customer record, update the requester profile.
Good: Send the user's token, fetch the user's record, update the user's profile.

Not a finding when the terms denote genuinely different roles.
