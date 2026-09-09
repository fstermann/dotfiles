---
id: ref-vague-pronoun
name: Vague pronoun
family: referential
pack: core
severity: warning
fix: arg
evidence: RE
message: Sentence-initial pronoun with an ambiguous or distant antecedent.
sniffers:
  - kind: deterministic
    pattern: '(^|[.!?]"?[[:space:]]+)(This|That|It|These|Those)[[:space:]]+(is|are|was|were|will|would|should|shall|can|could|may|might|means|makes|does|did|has|have|gives|breaks|causes|requires|needs|allows|refers|happens|leads)\b'
    confidence: medium
    hook_safe: false
  - kind: model
    confidence: medium
    hook_safe: false
---

A sentence-initial bare demonstrative used as a pronoun ("This is...", "It should...") whose
antecedent is ambiguous or distant. The reader, and a model, must guess which of several prior
nouns the pronoun points at.

The pattern is a trigger only: it finds sentence-initial `This/That/It/These/Those` followed by a
verb, which marks pronoun use rather than a determiner ("This value" does not fire). The model then
adjudicates whether the antecedent is actually ambiguous.

Bad:  The parser reads the config and the loader reads the manifest. This is then cached.
Good: The parser reads the config and the loader reads the manifest. The parsed config is cached.

Not a finding when exactly one antecedent is in scope, when the demonstrator is a determiner ("This
function returns..."), or inside a quoted example or code block.
