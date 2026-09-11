# sniff development

`sniff` combines deterministic detectors with LLM adjudication. `check` emits unconfirmed
candidates, `rules` emits the semantic rule bundle, and `report` renders confirmed findings.

## Development

- Run `uv sync --project .` after installation. Vale is required; other adapters are required only
  when selected rules use them.
- Run tests with `uv run --project . python -m unittest discover -s tests`.
- Keep the launcher, CLI, and bundled rule registry version-aligned.
- Keep runtime instructions in `SKILL.md`. Put maintainer guidance here and configuration details
  in `CONFIG.md`.

## Invariants

- A deterministic result remains a candidate until the LLM confirms it.
- Every selected LLM rule is evaluated, including rules that also have a deterministic detector.
- The rule registry and layered configuration own severity; the LLM never changes it.
- `--fix` applies only detector-declared safe fixes. It never applies unsafe or LLM-authored edits.
- The report renderer owns presentation. Change formatting in `src/sniff_cli/report.py` and its
  tests, not in `SKILL.md`.
- Detector failures are errors, not silently reduced coverage.

## CLI contract

```text
sniff check <paths...> [--profile NAME] [--format human|report|jsonl] [--fail-on LEVEL] [--fix]
sniff rules [--target PATH] [--profile NAME] [--format llm|jsonl]
sniff report [--project-root PATH] [--format auto|terminal|markdown]
```

Exit codes are `0` for success below the failure threshold, `1` when the threshold is reached, and
`2` for invalid input, configuration, or detector failure. The default threshold is `error`.

`check` runs deterministic engines only. Explicit files are checked even when ignored. Git
directory discovery includes tracked files plus untracked, non-ignored files. The `document`
profile does not expand into source files.

## Rule files

Each `rules/<id>.md` contains YAML frontmatter and the LLM guidance body:

```markdown
---
id: lex-loophole
name: Loophole or escape clause
family: lexical
applies_to: [core, spec]
severity: warning
fix: manual
evidence: ISO
message: Optional-clause phrase makes the requirement skippable.
sniffers:
  - kind: vale
    pattern: '\b(if possible|where applicable)\b'
    confidence: high
    hook_safe: false
  - kind: llm
    confidence: medium
    hook_safe: false
---

What the smell is and why it matters.

Bad: An example violation.
Good: A corrected example.

Not a finding when: the contextual exclusions.
```

The ID must match the filename stem. Supported sniffer kinds are `vale`, `ruff`, and `llm`. Vale
requires `pattern`; Ruff requires its native `rule` code. Every deterministic rule also needs an
`llm` sniffer unless it declares `llm_exempt: true`. Do not add arbitrary shell-command sniffers.

Keep detector configuration and measurement metadata out of the LLM bundle. `sniff rules` emits
only the ID, effective severity, message, and guidance body.

Personal rules live in `$XDG_CONFIG_HOME/sniff/rules/`, falling back to `~/.config/sniff/rules/`.
Project rules live in `.sniff/rules/`. Duplicate IDs are errors. See `CONFIG.md` for precedence.

`hook_safe` certifies precision of at least 0.90 over at least 25 hand-labelled candidates. It does
not control LLM evaluation or severity. See `MEASUREMENTS.md`.

Vale owns prose and markup parsing. Ruff and future adapters own their source languages. Register
rules explicitly with an adapter rather than recreating its parser.
