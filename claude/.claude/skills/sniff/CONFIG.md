# sniff configuration

Configuration is optional. `sniff` layers settings in this order:

1. Bundled defaults in `config/defaults.toml`.
2. `$XDG_CONFIG_HOME/sniff/sniff.toml`, falling back to `~/.config/sniff/sniff.toml`.
3. The nearest project `sniff.toml`, searching upward from the target and stopping at the Git root.
4. CLI flags.

For targets outside Git, project discovery searches upward and uses the nearest config. Pass
`--config <path>` to choose a project configuration explicitly. Mapping values merge recursively;
lists extend earlier lists without duplicates; scalar values override earlier values.

## Example

```toml
version = 1
default_profile = "document"
fail_on = "warning"

# Extend a bundled profile. Lists layer on top of bundled values.
[profiles.document]
exclude = ["vendor/**", "generated/**"]
exclude_rules = ["lex-politeness-padding"]

# Add a project-specific profile. `core` is explicit for custom profiles.
[profiles.release-notes]
tags = ["core", "document", "release-notes"]
include = ["CHANGELOG.md", "docs/releases/**/*.md"]
exclude = []
include_rules = []
exclude_rules = []

# Rule policy overrides. These do not redefine detector behavior.
[rules.lex-subjective]
enabled = false

[rules.lex-open-ended]
severity = "error"

# Configure developed integrations. A selected adapter that is disabled or missing is an error.
[adapters.vale]
enabled = true
executable = "vale"

[adapters.ruff]
enabled = true
executable = "ruff"
```

Valid severities are `suggestion`, `warning`, and `error`. The LLM confirms or rejects findings
but never changes their effective severity.

## Custom rules

Place personal rules in `$XDG_CONFIG_HOME/sniff/rules/` and repository rules in
`.sniff/rules/`. They use the rule schema documented in `SKILL.md`. A project rule extends the
registry; it cannot silently replace a bundled or personal rule. Duplicate IDs fail with both file
paths in the error.
