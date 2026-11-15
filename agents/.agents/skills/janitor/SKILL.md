---
name: janitor
description: "Scan a repo for dead code, inconsistencies, stale config and duplication, then fix the findings the user picks. Invoke by name (janitor), optionally with a path to limit the scan."
disable-model-invocation: true
---

Scan, report grouped findings, let the user pick, fix only what they picked.

Scope is the path in the arguments, else the repo root. Skip vendored, generated and gitignored files.

## Rules

- Never edit before the user picks.
- Before calling anything dead or stale, search every reference: code, strings, configs, docs, scripts.
- Never install a tool.
- Never commit or push.

## Step 1: Scan

Start from the repo's own rules: AGENTS.md, CLAUDE.md, README, manifests, CI and lint config. A convention the repo states wins over one you infer. Then read, grep and run checks in whatever order the leads suggest.

Run linters, analyzers and the repo's own check scripts that are already installed. Examples: `knip`, `tsc --noEmit`, eslint, `vulture`, `ruff check`, `shellcheck`, `staticcheck`, `go vet`. Treat tool output as leads. Dynamic imports, reflection, entry points and config-driven loading cause false positives, so confirm each lead by reading the code.

Look for anything that makes the repo harder to maintain. Typical categories:

- Dead code: unused functions, exports, files, dependencies, unreachable branches, commented-out blocks.
- Inconsistencies: one concept named two ways, two patterns for the same job, docs or comments that contradict the code.
- Stale config: references to paths, scripts, env vars or packages that no longer exist; orphaned config entries; dated TODOs.
- Duplication: logic copied in two or more places that could share one implementation.
- Repo-specific: violations of rules the repo states, such as a registry or index that is out of sync with the files it lists.

Add a category when findings don't fit these.

## Step 2: Record findings

Each finding needs:

- Category
- Location as `path:line`
- One-sentence claim plus the evidence behind it (tool output, zero grep hits, the two conflicting sites)
- Confidence: high (verified, safe to change) or medium (likely, but a dynamic use or intent is possible)
- The planned fix in one line

Drop anything below medium. Drop style nits a formatter would settle.

## Step 3: Let the user pick

Present grouped findings and let the user choose which to fix. Use the host's structured question tool when available. If it supports multi-select, offer one question per category; otherwise number the findings and ask in chat for the selected numbers. Do not interpret a single-choice answer as approval for the whole category.

Each choice includes the location, evidence, confidence, and planned fix. Put high-confidence findings first. Split questions to fit the host's limits. Before asking, print the total count per category. Wait for the user's selections before fixing anything.

Skip a category with no findings. If nothing survives, say so and stop.

## Step 4: Fix

Apply only the selected fixes. Match the existing style. Remove only orphans your own fixes create. After fixing, rerun the checks you ran in Step 1 and report what changed, what the checks now say, and anything you could not verify.
