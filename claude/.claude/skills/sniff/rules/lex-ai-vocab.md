---
id: lex-ai-vocab
code: LEX015
name: AI-vocab banned word
family: lexical
applies_to: [core]
severity: warning
fix: manual
evidence: RE
llm_exempt: true
message: AI-vocab banned by house style. Use the plain word (leverage/utilize to use, facilitate to help).
sniffers:
  - kind: vale
    pattern: '\b(delve|delved|delving|delves|leverage|leverages|leveraged|leveraging|utilize|utilizes|utilized|utilizing|crucial|seamless|seamlessly|robust|robustly|underscore|underscores|underscored|underscoring|showcase|showcases|showcased|showcasing|foster|fosters|fostered|fostering|tapestry|pivotal|groundbreaking|vibrant|stunning|facilitate|facilitates|facilitated|facilitating|genuinely)\b'
    confidence: high
    hook_safe: true
    precision: 1.00   # house-style ban: any occurrence is a violation
    n: 0
---

Words that mark text as AI-generated. House style bans them outright; any occurrence is a violation.
Reach for the plain word: leverage/utilize become "use", facilitate becomes "help", crucial becomes
"key" or drop it.

Bad:  We leverage the API to facilitate a robust, seamless flow.
Good: We use the API for the flow.

Not a finding inside a quoted example or code block.
