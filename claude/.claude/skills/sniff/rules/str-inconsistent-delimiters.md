---
id: str-inconsistent-delimiters
code: STR006
name: Inconsistent formatting scheme
family: structural
applies_to: [prompt]
severity: warning
fix: auto
evidence: LLM
message: Mixed separator and heading conventions within one prompt.
sniffers:
  - kind: llm
    confidence: medium
    hook_safe: false
---

Heading and separator styles change within one prompt. Meaning-preserving format shifts move few-shot accuracy.

Bad:  ## Step 1, then **Step 2:**, then STEP 3 -.
Good: ## Step 1, ## Step 2, ## Step 3.

Not a finding when one scheme is used throughout.
