---
id: str-example-label-imbalance
name: Few-shot label imbalance
family: structural
applies_to: [prompt]
severity: warning
fix: manual
evidence: LLM
message: A skewed label distribution across few-shot examples; majority-label bias.
sniffers:
  - kind: llm
    confidence: medium
    hook_safe: false
---

Few-shot examples skew toward one label, biasing the model toward the majority.

Bad:  Nine positive examples and one negative.
Good: Five positive and five negative.

Not a finding when the true prior is genuinely skewed.
