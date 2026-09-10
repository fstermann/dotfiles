---
name: sniff
description: Manually review any text, prompt, specification, document, comment, docstring, or registered source-code pattern for defects. Use only when the user explicitly invokes sniff or asks to sniff text; never run it implicitly during ordinary review.
---

# sniff

Finds **smells**: defects that make text or code ambiguous, unverifiable, contradictory, or easy
to misuse. A **sniffer** is one way to detect a rule; a **candidate** is detector output awaiting
LLM adjudication; a **finding** is a confirmed violation.

Invocation is manual only. Infer the target and profile from the user's request. State the inferred
profile briefly. If the target or profile is genuinely ambiguous, ask one clarification question.

## Profiles

- `document`: Markdown and other standalone prose.
- `prompt`: prompts and agent instructions.
- `spec`: requirements and specifications.
- `code`: source-code comments, docstrings, and registered code-linter rules.
- `all`: every registered rule and supported input type.

Rules tagged `core` apply to every ordinary profile. Project-defined profiles are allowed through
`sniff.toml`. The CLI defaults to `document`; skill usage infers the profile.

## Run a sniff

The bundled CLI lives beside this file. Vale is required. Other adapters, such as Ruff, become
required only when the selected rules use them.

Run `uv sync --project <skill-directory>` once after installation, then install Vale through the
platform package manager. The `sniff` launcher uses the skill-local environment, keeping the CLI
and rule registry version-aligned.

1. Run deterministic sniffers and read their JSONL candidates:

   ```sh
   ./sniff check <path...> --profile <profile> --format jsonl
   ```

   Use `-` instead of a path for text that exists only in the conversation and pass that text on
   stdin. Do not persist conversational text merely to inspect it.

2. Load the complete applicable LLM rule bundle:

   ```sh
   ./sniff rules --target <path> --profile <profile>
   ```

   For conversational stdin, omit `--target`; configuration discovery starts at the working
   directory.

3. Read the target once and evaluate **every emitted LLM sniffer**, including rules that also have
   a Vale or Ruff sniffer. Deterministic candidates focus attention but do not limit the semantic
   pass. Independently find violations the deterministic engines missed.

4. Adjudicate every deterministic candidate against the rule guidance, especially its exclusions.
   Reject false positives. A Vale or Ruff candidate is not a final finding until confirmed.

5. Report confirmed findings only. Deduplicate by rule and source span. Keep the configured
   severity unchanged; the LLM must never raise or lower it.

6. Send the confirmed findings as JSONL on stdin to the deterministic report renderer and return
   its stdout verbatim:

   ```sh
   ./sniff report --project-root <project-root>
   ```

   Each object must contain `path`, `line`, `column`, `end_line`, `end_column`, `rule`, `severity`,
   `span`, `message`, and `source`. Use `vale -> llm confirmed`, `ruff -> llm confirmed`, or
   `llm only` for `source`. For conversational stdin or an inaccessible source path, also include
   the complete input as `source_text` so the renderer can construct the excerpt. Do not persist
   this JSONL merely to render it.

The default is report-only. When the user explicitly requests `--fix`, run `sniff check --fix`.
The CLI applies only detector-declared safe fixes and automatically rechecks. Then perform the LLM
pass on the resulting text and report remaining findings. Never apply unsafe or LLM-authored edits
under `--fix`.

## Reporting

The `sniff report` command owns this presentation. Do not manually reconstruct or restyle its
output when the renderer is available.

For one or more confirmed findings, begin with this compact banner and summary:

```text
 ___ _  _ ___ ___ ___
/ __| \| |_ _| __| __|
\__ \ .` || || _|| _|
|___/_|\_|___|_| |_|

<finding-count> findings across <file-count> files
```

Use the singular `finding` or `file` when its count is one. Do not add an emoji or a Markdown
heading to the banner or to individual findings.

Group findings by file and preserve source order within each file. Print the file once as a
clickable Markdown link whose label is the project-relative `<file>:<line>` and whose destination
is the absolute file path with the line suffix. For stdin or a location that cannot be linked,
print the location as plain text. Do not include the column in the location label.

Render each finding in this order:

1. The finding label: uppercase severity in brackets, then the rule ID, then provenance. Use
   `└── ` before an error. Align warnings and suggestions with the text after that connector, but
   do not put a connector before them. Bold `[<SEVERITY>] <rule-id>` and render provenance as
   italic `· via Vale → LLM`, `· via Ruff → LLM`, or `· via LLM`.
2. A fenced `text` excerpt showing the user's source before the diagnosis. Prefix excerpt rows
   with a continuing `│` rail. Mark the physical line containing the finding with `›`, show line
   numbers, wrap continued text under an empty line-number field, and place a caret row under each
   offending span.
3. The concise contextual explanation, italicized and prefixed with `└── ` at the same indentation
   as the excerpt rail.

The excerpt may contain at most three visible source-text rows. Blank source rows and caret rows do
not count toward that limit. Preserve the complete offending span. Wrap a long physical line when
needed, then spend any remaining rows on immediately adjacent context. When source must be omitted
at the outer edges, mark the omission with `… ` at the beginning of the first source row or ` …`
at the end of the last source row. Never use an ellipsis inside or instead of the offending span.
Keep multiple findings at the same file location as siblings; do not nest one finding beneath
another.

Example:

````markdown
[claude/.claude/skills/backcast/SKILL.md:24](/absolute/project/claude/.claude/skills/backcast/SKILL.md:24)
    **[WARNING] lex-loophole** · *via Vale → LLM*

```text
    │ › 24 │ … hard constraints (stay deployable? stable public API?);
    │      │ success metric where applicable; what's out of scope. Then by type:
    │      │                ^^^^^^^^^^^^^^^^
    │   25 │
    │   26 │ - Feature: the new capability; acceptance criteria + edge cases …
```

    └── *The instruction does not define when a success metric is required.*
````

Severity is policy from the rule registry plus layered configuration. Provenance is visible, but
do not expose hidden reasoning. If there are no confirmed findings, say so and mention any rejected
candidate count. If a detector fails, report incomplete coverage; do not silently skip it.

## CLI contract

```text
sniff check <paths...> [--profile NAME] [--format human|report|jsonl] [--fail-on LEVEL] [--fix]
sniff rules [--target PATH] [--profile NAME] [--format llm|jsonl]
sniff report [--project-root PATH] [--format auto|terminal|markdown]  # reads JSONL from stdin
```

`check` runs registered deterministic engines only. `--format report` uses the terminal-safe
version of the same presentation without Markdown fences or markup. It correctly labels its
unadjudicated results as candidates and shows provenance as `via Vale` or `via Ruff`. The report
command defaults to `auto`: Claude Code and Codex environments get Markdown; other environments get
terminal output. Pass an explicit format to override detection. Its exit codes are:

- `0`: completed without findings at or above the failure threshold.
- `1`: findings reached the failure threshold.
- `2`: invalid input/configuration or detector failure.

The default failure threshold is `error`. Explicit files are checked even when ignored. Directory
discovery inside Git includes tracked files plus untracked, non-ignored files. The `document`
profile never expands into source files; comments, docstrings, and code rules belong to `code`.

## Rule files

The rule format is the product. One Markdown file in `rules/` defines one rule; project and user
extensions use the same schema. The body is guidance for the LLM.

```markdown
---
id: lex-loophole            # must equal filename stem
name: Loophole or escape clause
family: lexical
applies_to: [core, spec]    # multi-valued tags
severity: warning           # error | warning | suggestion
fix: manual                 # auto | arg | manual
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

Supported sniffer kinds are integrations developed with `sniff`:

- `vale`: prose regex/style detector; requires `pattern`.
- `ruff`: registered Ruff detector; requires its native `rule` code.
- `llm`: contextual semantic detector; the Markdown body supplies its guidance.

Every deterministic rule must also have an `llm` sniffer unless it explicitly declares
`llm_exempt: true`. Do not add arbitrary shell-command sniffers. Keep detector configuration and
measurement metadata out of the model bundle; `sniff rules` emits only ID, effective severity,
message, and guidance body.

Custom rules live in `$XDG_CONFIG_HOME/sniff/rules/` (falling back to
`~/.config/sniff/rules/`) or project `.sniff/rules/`. Duplicate IDs across any layer are an error.
See `CONFIG.md` for configuration and precedence.

`hook_safe` remains a precision certification: at least 0.90 precision over at least 25
hand-labelled candidates. It does not control LLM evaluation or severity. See `MEASUREMENTS.md`.

## Scope

`sniff` orchestrates registered detectors; it does not recreate their parsers. Vale owns prose and
markup parsing. Ruff and future developed adapters own their source languages. A rule only enters
an external adapter when it is explicitly registered with that adapter in `sniff`.
