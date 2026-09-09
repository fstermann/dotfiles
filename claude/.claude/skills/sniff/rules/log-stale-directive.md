---
id: log-stale-directive
name: Stale directive
family: logical
pack: core
severity: warning
fix: manual
evidence: prac
message: References a tool, file or step that no longer exists.
sniffers:
  - kind: model
    confidence: medium
    hook_safe: false
---

An instruction pointing at something removed. Detecting it needs an inventory of current tools and files.

Bad:  Run `make lint` before committing, after `make lint` was deleted.
Good: Run `npm run lint` before committing.

Not a finding when the referenced item still exists.
