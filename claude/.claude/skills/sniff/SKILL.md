---
name: sniff
description: Review a doc, spec, instruction file or prompt for text-level defects (smells) like vague quantifiers, ambiguous pronouns, loopholes and contradictory constraints. Reports findings; does not rewrite. Trigger on "sniff this", "review this doc/prompt for smells", or a request to check instructional text for ambiguity.
---

# sniff

Reviews instructional text for **smells**: text-level defects that make a doc, spec or prompt
ambiguous, unverifiable or self-contradictory. A **sniffer** detects a smell; a **finding** is one
instance.

Report-only. Rewriting is a separate mode and needs write access this review does not.

The rule format is the product. Each rule is one file in `rules/`. Registering a rule is adding a
file; the skill globs the directory, so a new file is live with no code change.

## Rule file format

One file per rule. Frontmatter is machine-readable; the body is what the reviewer reads.

```markdown
---
id: lex-loophole          # == filename stem
name: Loophole or escape clause
family: lexical            # lexical | referential | logical | structural | pragmatic
pack: core                 # core | prompt | spec
severity: warning          # error | warning | suggestion
fix: manual                # auto | arg | manual
evidence: ISO              # ISO | RE | LLM | prac
message: One line stating the defect, printed with each finding.
sniffers:
  - kind: deterministic    # deterministic | model
    pattern: '\b(if possible|where applicable)\b'   # plain ERE, runnable by grep -niE
    confidence: high       # high | medium | low
    hook_safe: false
---

Prose the reviewer reads: what the smell is and why it matters.

Bad:  <example that should fire>
Good: <example that should not>

Not a finding when: <exclusions the model applies>.
```

Rules:

- `id` must equal the filename stem.
- A `deterministic` sniffer must carry a `pattern` that is plain ERE runnable by `grep -nE`
  unchanged. A `model` sniffer carries no pattern.
- `message` is the one-line finding text. A pure-deterministic rule needs only its frontmatter at
  runtime; the body loads into context only for rules with a `model` sniffer. Keep bodies short.
- `hook_safe` is false until precision justifies otherwise: a deterministic sniffer becomes
  hook-eligible at precision >= 0.90 on >= 25 hand-labeled hits. `hook_safe` is the precision gate;
  `severity` then decides whether the hook blocks (`error`) or warns (`warning`). Optional
  `precision` and `n` fields on a sniffer record the last measurement. See `MEASUREMENTS.md`;
  `lex-vague-quantifier`, `lex-ambiguous-adverb` and `lex-open-ended` are certified.
- `pack` scopes the rule. `core` applies to any instructional text; `prompt` adds LLM-specific
  rules and implies `core`; `spec` promotes a few rules to `error` for requirements docs.

## Running a review

1. **Pick the pack.** `core` for prose and docs; `prompt` for a prompt or system instruction;
   `spec` for a requirements document. `prompt` and `spec` both include `core`.
2. **Load rules.** Glob `rules/*.md`. Keep rules whose `pack` is in scope. If the glob is empty,
   report "0 rules loaded" and stop.
3. **Deterministic pass.** Run the script; it does the scoping and the pattern pass:

   ```sh
   ./sniff.sh <target> <pack>
   ```

   It blanks excluded spans (fenced code blocks, `Bad:`/`Good:` example lines, block quotes,
   inline back-ticked spans) so a smell quoted as an example is not flagged, then runs each
   in-scope deterministic pattern case-insensitively and prints candidate findings. A smell inside
   a quoted example is not a defect; the same text in an instruction is.
4. **Model pass.** Read the in-scope text once.
   - For each `model` sniffer of the active packs, report instances.
   - When a rule pairs a `deterministic` sniffer with a `model` sniffer, the pattern only
     generates candidates; adjudicate each candidate against the rule body's "Not a finding when"
     clause and keep only the real defects.
5. **Report.** Group findings by smell. Per finding: file, line, the offending span, severity, and
   which sniffer fired. A smell flagged by two independent sniffers ranks above one flagged by one.

## Reporting format

```
<file>:<line>  [<severity>]  <rule-id>
  span:   "<offending text>"
  why:    <the rule's `message` field>
```

Findings are cheap to dismiss: one comment line. Do not rewrite. If asked to fix, say that
rewriting is a separate mode.

## Scope

Single documents, Markdown and plain text. Not grammar, spelling or style preference. Not a claim
that fixing a smell improves any downstream outcome; a static checker cannot know that.
