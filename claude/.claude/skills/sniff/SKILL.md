---
name: sniff
description: Review text, prompts, specifications, documents, comments, docstrings, or registered source-code patterns for ambiguity, contradiction, unverifiable requirements, and related defects. Use only when the user explicitly invokes sniff or asks to sniff text; never run it during ordinary review.
---

# sniff

A deterministic detector emits **candidates**. The LLM confirms or rejects them and can add
findings that detectors missed.

Infer the target and profile from the request:

- `document`: standalone prose
- `prompt`: prompts and agent instructions
- `spec`: requirements and specifications
- `code`: comments, docstrings, and registered code-linter rules
- `all`: every registered rule and supported input type

Project-defined profiles may also exist in `sniff.toml`.

## Run a sniff

The bundled CLI lives beside this file.

1. Run deterministic detectors and read their JSONL candidates:

   ```sh
   ./sniff check <path...> --profile <profile> --format jsonl
   ```

   For conversational text, pass it through stdin using `-`; do not persist it. Use `--fix` only
   when explicitly requested. It applies detector-declared safe fixes and rechecks.

2. Load the complete applicable LLM rule bundle:

   ```sh
   ./sniff rules --target <path> --profile <profile>
   ```

   Omit `--target` for conversational stdin.

3. Read the target once and evaluate every emitted rule. Deterministic candidates guide but do not
   limit this pass. Adjudicate each candidate against the rule's exclusions and independently find
   violations the detectors missed.

4. Report confirmed findings only. Deduplicate by rule and source span, and preserve the configured
   severity.

5. Send the confirmed findings as JSONL on stdin to:

   ```sh
   ./sniff report --project-root <project-root>
   ```

   Each object requires `path`, `line`, `column`, `end_line`, `end_column`, `rule`, `code`,
   `severity`, `span`, `message`, and `source`. Preserve the rule's emitted `code`. Set `source` to
   `vale -> llm confirmed`, `ruff -> llm confirmed`, or `llm only`. Include the complete input as
   `source_text` for stdin or inaccessible paths. Do not persist this JSONL.

Return the renderer's output without reconstructing or restyling it. If a detector fails, report
the incomplete coverage.
