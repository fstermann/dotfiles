---
name: self-improve
description: Turn conversation findings into durable Claude configuration — CLAUDE.md rules, skills, hooks, settings, or memory. Runs in session mode (review the current conversation, usually triggered automatically by the Stop-hook checkpoint) or history mode (one-time sweep of past transcripts across all projects). Trigger on "self-improve", "what did you learn", "update your instructions", "analyse my past conversations", or the self-improvement checkpoint hook.
---

Convert what a conversation taught into config that changes future behaviour. You propose, the user decides — nothing is written before they approve each edit.

Two modes, picked from how you were invoked (ask only if genuinely ambiguous):

- **Session mode** — review the current conversation. The default, and what the Stop-hook checkpoint asks for.
- **History mode** — one-time sweep across past transcripts. Use on first setup or when asked to analyse past conversations.

## What counts as a finding

A finding is **durable** and **actionable**: it would change your behaviour in a *future, unrelated* session.

Qualifies:
- A correction the user made more than once, here or historically.
- A stated standing preference ("always X", "never Y", "from now on").
- A repeated manual workflow a skill or hook could carry.
- Friction the user hit repeatedly — a permission prompt, missing setting.
- A rule already in config that you demonstrably violated — that is a *phrasing* bug in the existing rule, not a new rule.

Does not qualify:
- One-off task facts, this repo's structure, anything git or the code already records.
- Anything already covered by existing config — check first; sharpen the existing line instead of adding a near-duplicate.
- Your guesses about what the user *might* want.
- Politeness noise: a single "no", a changed mind, a mid-task scope change.

**Finding nothing is a valid, common result.** Say so in one line and stop. A manufactured rule costs the user context in every future session.

## Where a finding goes

| Finding | Destination |
|---|---|
| Behavioural rule, applies everywhere | `~/.dotfiles/claude/.claude/CLAUDE.md` |
| Behavioural rule, one repo only | that repo's `CLAUDE.md` |
| Multi-step procedure worth invoking by name | new/edited skill under `~/.dotfiles/claude/.claude/skills/` |
| Must run deterministically on an event | hook in `~/.dotfiles/claude/.claude/settings.json` |
| Permission, env var, tool config | `settings.json` |
| A fact about the user or project, not a rule | memory dir (see the memory instructions) |

Prefer the smallest destination that works: a CLAUDE.md rule is paid for on every request in every project; a skill only when triggered. Procedural findings belong in a skill.

Global config lives in the dotfiles repo, never in `~/.claude` directly — those paths are symlinks. New scripts there need a symlink too (`ln -s ../.dotfiles/claude/.claude/<file> ~/.claude/<file>`).

## Session mode

1. Re-read the conversation for the signals above, weighting what the *user* said over what you inferred.
2. Check current config before proposing. A finding that duplicates an existing rule is not a finding; one that contradicts a rule is a conflict to raise explicitly.
3. Draft each finding as a concrete diff — the exact line you would add, not a theme ("be more careful with X" is not proposable).
4. Propose via `AskUserQuestion`, **one question per finding**, showing the exact text and destination file. Offer at least apply-as-drafted / skip; add a variant when there's a real placement or wording choice.
5. Apply only what was approved, then report one line per edit: file and what changed.

Keep the pass short. Three findings is a lot; more than five means the bar was too low.

## History mode

One-time or occasional; it reads a lot of text, so say what it will do before starting.

1. Mine the transcripts:

   ```bash
   python3 ~/.claude/skills/self-improve/mine-transcripts.py --since 2026-01-01 > /tmp/self-improve-hits.json
   ```

   Flags: `--since ISO_DATE`, `--project SUBSTRING`, `--limit N` (default 400), `--root PATH`. Returns matched user prompts with the preceding assistant message and a `signal_counts` summary.

2. Read `signal_counts` first — it tells you which failure mode dominates. Then read `silent_signals`: tool calls the user **rejected** or **interrupted**, each with the call in flight. These need no complaint to exist, so they catch what the user worked around instead of voicing. Read the `call` field, not the words; one veto usually produces both a `rejected` and an `interrupt` record, so count distinct calls.
3. Cluster hits by *underlying cause*, not wording. Ten "no, simpler" corrections across eight projects are one strong finding.
4. **Rank by frequency, drop the tail.** The regex over-matches; require a pattern across at least two sessions before proposing — unless a single hit is an unambiguous standing preference or a verifiable config violation. Say how many sessions each proposal rests on.
5. Distinguish the fix: config never covered this → new rule; config covered it and it happened anyway → *rewrite* the existing rule (a second rule saying the same thing won't work either).
6. Propose via `AskUserQuestion`, one question per cluster, citing session count and one representative quote.

The miner is a regex pass with no judgment — expect a high false-positive rate and filter hard.

## Rules

- Never edit config without per-edit approval, however obvious the finding.
- Never edit a repo outside the current working tree without saying which repo you're touching.
- Match the target file's voice and structure. CLAUDE.md is terse and imperative — a section that reads differently from its neighbours is a bad edit even if the content is right.
- Additions must be paid for: if you add a rule, check whether it makes an existing one redundant and propose removing that one in the same pass.
- Do not touch `~/.claude/.self-improve/` — it is hook state, not config.
