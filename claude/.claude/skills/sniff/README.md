# sniff

`sniff` reviews prose and source-code text for ambiguity, contradiction, unverifiable
requirements, missing context, and related defects. Deterministic detectors produce candidates;
an LLM adjudicates those candidates and checks contextual rules that cannot be expressed reliably
as patterns.

Rule slugs remain readable and configurable, while stable Ruff-style codes make findings easy to
scan and reference:

```text
　　[WARNING LOG010] log-universal-quantifier · via LLM
```

## Installation

The launcher uses the skill-local virtual environment when present:

```sh
uv sync --project .
```

[Vale](https://vale.sh/) is required for prose detectors. Other adapters, currently Ruff, are
required only when a selected rule uses them; a selected adapter that is disabled or unavailable
is an error.

## Usage

Run deterministic detectors:

```sh
./sniff check <path...> --profile document
./sniff check <path...> --profile spec --format report
./sniff check <path...> --profile code --format jsonl
```

Pass `-` to inspect stdin. Explicit files are checked even when ignored; directory discovery uses
tracked files plus untracked, non-ignored files. `--fix` applies detector-declared safe fixes and
rechecks. It does not apply LLM-authored edits.

The built-in profiles are:

| Profile | Scope |
|---|---|
| `document` | Standalone prose and markup |
| `prompt` | Prompts and agent instructions |
| `spec` | Requirements and specifications |
| `code` | Comments, docstrings, and registered code-linter rules |
| `all` | Every registered rule and supported input type |

The skill's LLM workflow also uses these commands:

```sh
./sniff rules --target <path> --profile <profile>
./sniff report --project-root <project-root>
```

`rules` emits the applicable semantic guidance. `report` reads confirmed JSONL findings on stdin
and renders terminal or Markdown output. Its default format is Markdown in Claude Code and Codex,
and terminal output elsewhere. Run `./sniff <command> --help` for all options.

Exit status is `0` below the configured failure threshold, `1` when the threshold is reached, and
`2` for invalid input, configuration, or detector failure. The default threshold is `error`.

## Configuration

Configuration is optional and layers in this order:

1. Bundled defaults in `config/defaults.toml`.
2. `$XDG_CONFIG_HOME/sniff/sniff.toml`, falling back to `~/.config/sniff/sniff.toml`.
3. The nearest `sniff.toml` found by searching upward from the target to the Git root.
4. CLI flags.

Mappings merge recursively, lists extend without duplicates, and scalar values override earlier
values. Outside a Git repository, discovery searches upward and uses the nearest configuration.
Use `--config <path>` to select a project configuration explicitly.

```toml
version = 1
default_profile = "document"
fail_on = "warning"

# Extend a bundled profile.
[profiles.document]
exclude = ["vendor/**", "generated/**"]
exclude_rules = ["lex-politeness-padding"]

# Define a project-specific profile. Include `core` explicitly when wanted.
[profiles.release-notes]
tags = ["core", "document", "release-notes"]
include = ["CHANGELOG.md", "docs/releases/**/*.md"]
exclude = []
include_rules = []
exclude_rules = []

# Override rule policy without redefining detector behavior.
[rules.lex-subjective]
enabled = false

[rules.lex-open-ended]
severity = "error"

[adapters.vale]
enabled = true
executable = "vale"

[adapters.ruff]
enabled = true
executable = "ruff"
```

Valid severities are `suggestion`, `warning`, and `error`. Configuration owns effective severity;
the LLM does not change it.

### Custom rules

Place personal rules in `$XDG_CONFIG_HOME/sniff/rules/` (or `~/.config/sniff/rules/`) and project
rules in `.sniff/rules/`. A custom rule extends the registry and cannot replace an existing rule.
Rule IDs and codes must both be unique across all layers.

Each `rules/<id>.md` contains YAML frontmatter and LLM guidance:

```markdown
---
id: lex-loophole
code: LEX005
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

The ID must match the filename stem. Codes use three uppercase family letters and three digits,
such as `LEX005`; assign the next unused number and never renumber an existing rule. Vale sniffers
require `pattern`, while Ruff sniffers require the native Ruff `rule` code. Every deterministic
rule also needs an LLM sniffer unless it declares `llm_exempt: true`.

## Development and evaluation

Run the tests with:

```sh
uv run --project . python -m unittest discover -s tests
```

Contributor guidance lives in [AGENTS.md](AGENTS.md). Detector certification evidence lives in
[eval/MEASUREMENTS.md](eval/MEASUREMENTS.md); the separate downstream-effect experiment is
described in [eval/EVAL.md](eval/EVAL.md).
