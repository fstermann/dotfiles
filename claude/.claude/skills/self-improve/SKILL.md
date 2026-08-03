---
name: self-improve
description: Turn conversation findings into durable Claude configuration — CLAUDE.md rules, skills, hooks, settings, or memory. Runs in session mode (review the current conversation, usually triggered automatically by the Stop-hook checkpoint) or history mode (one-time sweep of past transcripts across all projects). Trigger on "self-improve", "what did you learn", "update your instructions", "analyse my past conversations", or the self-improvement checkpoint hook.
---

Convert what a conversation taught into configuration that changes future behaviour. Every edit needs explicit user approval — you propose, the user decides, nothing is written before they say yes.

Two modes. Pick from how you were invoked; if genuinely ambiguous, ask.

- **Session mode** — review the current conversation. The default, and what the Stop-hook checkpoint asks for.
- **History mode** — one-time sweep across past transcripts. Use when the user asks to analyse past conversations, or on first setup.

## What counts as a finding

A finding must be **durable** and **actionable**: it would change your behaviour in a *future, unrelated* session.

Qualifies:
- A correction the user had to make more than once, here or historically.
- A stated standing preference ("always X", "never Y", "from now on").
- A repeated manual workflow that a skill or hook could carry.
- A permission prompt, missing setting, or friction the user hit repeatedly.
- A rule already in config that you demonstrably violated — that is a *phrasing* bug in the rule, not a new rule.

Does not qualify:
- One-off task facts, this repo's structure, anything git or the code already records.
- Something already covered by existing config — check first, and prefer sharpening the existing line over adding a near-duplicate.
- Your own guesses about what the user *might* want.
- Politeness noise: a single "no", a changed mind, a scope change mid-task.

**Finding nothing is a valid, common result.** Say so in one line and stop. Never pad the list to look useful — a manufactured rule costs the user context in every future session.

## Where a finding goes

| Finding | Destination |
|---|---|
| Behavioural rule, applies everywhere | `~/.dotfiles/claude/.claude/CLAUDE.md` |
| Behavioural rule, one repo only | that repo's `CLAUDE.md` |
| Multi-step procedure worth invoking by name | new/edited skill under `~/.dotfiles/claude/.claude/skills/` |
| Must run deterministically on an event | hook in `~/.dotfiles/claude/.claude/settings.json` |
| Permission, env var, tool config | `settings.json` |
| A fact about the user or project, not a rule | memory dir (see the memory instructions) |

Global config lives in the dotfiles repo, never in `~/.claude` directly — those paths are symlinks. New scripts there need a symlink too (`ln -s ../.dotfiles/claude/.claude/<file> ~/.claude/<file>`).

Prefer the smallest destination that works. A rule in CLAUDE.md is paid for on every request in every project; a skill is paid for only when triggered. If a finding is procedural, it belongs in a skill.

## Session mode

1. Re-read the conversation for the signals above. Weight what the *user* said over what you inferred.
2. Check current config before proposing — read the relevant CLAUDE.md, skill, or settings section. A finding that duplicates an existing rule is not a finding; a finding that contradicts one is a conflict to raise explicitly.
3. Draft each finding as a concrete diff, not a theme. "Be more careful with X" is not proposable; the exact line you would add is.
4. Propose with `AskUserQuestion` — **one question per finding**, so each is accepted or rejected on its own. Show the exact text to be written and the destination file. Offer at least: apply as drafted / skip. Add a variant option when there is a real placement or wording choice.
5. Apply only what was approved. Then report in one line per edit: file and what changed.

Keep the whole pass short. Three findings is a lot; more than five means the bar was set too low.

## History mode

One-time, or occasional. It reads a lot of text — say what it will do before starting.

1. Mine the transcripts:

   ```bash
   python3 ~/.claude/skills/self-improve/mine-transcripts.py --since 2026-01-01 > /tmp/self-improve-hits.json
   ```

   Flags: `--since ISO_DATE`, `--project SUBSTRING`, `--limit N` (default 400), `--root PATH`. It returns matched user prompts with the preceding assistant message and a `signal_counts` summary.

2. Read `signal_counts` first — it tells you which failure mode dominates before you read a single hit.
3. Cluster the hits by *underlying cause*, not by wording. Ten "no, simpler" corrections across eight projects are one finding, and a strong one.
4. **Rank by frequency and drop the tail.** A cluster that appears once is noise; the regex is deliberately loose and over-matches. Require a pattern across at least three separate sessions before proposing it, and say how many sessions each proposal rests on.
5. Distinguish two cases, because the fix differs:
   - Config never covered this → propose a new rule.
   - Config covered it and it happened anyway → propose a *rewrite* of the existing rule. The old phrasing did not work; adding a second rule saying the same thing will not either.
6. Propose via `AskUserQuestion`, one question per cluster, as in session mode. Cite the session count and one representative quote per proposal.

The miner is a regex pass and has no judgment — it flags interrupts and any "no". Expect a high false-positive rate and filter hard.

## Rules

- Never edit config without per-edit approval, no matter how obvious the finding.
- Never edit a repo outside the current working tree without saying which repo you are touching.
- Match the target file's existing voice and structure. CLAUDE.md is terse and imperative — a new section that reads differently from its neighbours is a bad edit even if the content is right.
- Additions must be paid for: if you add a rule, check whether it makes an existing one redundant, and propose removing that one in the same pass.
- Do not touch `~/.claude/.self-improve/` — it is hook state, not config.
