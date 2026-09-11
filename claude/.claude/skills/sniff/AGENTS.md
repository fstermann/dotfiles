# sniff development

`sniff` combines deterministic detectors with LLM adjudication. `check` emits unconfirmed
candidates, `rules` emits the semantic rule bundle, and `report` renders confirmed findings.

## Development

- Keep user-facing installation, usage, configuration, and rule-schema documentation in
  `README.md`.
- Keep runtime instructions in `SKILL.md` and maintainer guidance here.
- Run tests with `uv run --project . python -m unittest discover -s tests`.
- Keep the launcher, CLI, and bundled rule registry version-aligned.

## Invariants

- A deterministic result remains a candidate until the LLM confirms it.
- Every selected LLM rule is evaluated, including rules that also have a deterministic detector.
- The rule registry and layered configuration own severity; the LLM never changes it.
- `--fix` applies only detector-declared safe fixes. It never applies unsafe or LLM-authored edits.
- The report renderer owns presentation. Change formatting in `src/sniff_cli/report.py` and its
  tests, not in `SKILL.md`.
- Detector failures are errors, not silently reduced coverage.

## Rule maintenance

Keep rule codes stable and unique. Do not add arbitrary shell-command sniffers. Keep detector
configuration and measurement metadata out of the LLM bundle; `sniff rules` emits only the ID,
code, effective severity, message, and guidance body.

`hook_safe` certifies precision of at least 0.90 over at least 25 hand-labelled candidates. It does
not control LLM evaluation or severity. Record the evidence in `eval/MEASUREMENTS.md`.

Vale owns prose and markup parsing. Ruff and future adapters own their source languages. Register
rules explicitly with an adapter rather than recreating its parser.
