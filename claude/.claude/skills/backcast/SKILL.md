---
name: backcast
description: Use when the user wants a plan to get from today's codebase to a substantially different end-state, especially when that destination is fuzzy or stated as a solution rather than an outcome. Covers refactors, migrations, re-architectures, rewrites, and large multi-step features. Trigger on "help me plan/scope this", "how should I approach", "what's the roadmap for", or a named solution ("migrate to X", "rebuild as Y") whose underlying goal is unstated. Skip single decisions, one-step changes, and plans that are already concrete.
---

Plan backward from the end-state, not forward from today's code. Forward step-by-step planning drifts into local-optimum incrementalism — each step looks fine alone, the destination is never reckoned with, and the plan inherits the current code's shape. Fix the target first, then derive only the steps that reach it.

Three phases, run **strictly in order**: define the goal → pin the end-state → backcast the plan. Each phase is iterative — keep asking within it until the user explicitly confirms, then move on. Don't ask a later phase's questions until the current one is confirmed; a Phase 2 question (format, surface, structure) raised before the goal is locked presupposes the very thing Phase 1 exists to settle. Extra rounds are expected and fine; never merge or skip phases to save a turn.

Throughout:

- **Read before asking.** Determine from code, tests, configs, and deps anything you can; don't ask the user what the code can tell you.
- **Ask via `AskUserQuestion`** with concrete options to pick from; free-form only when options won't fit. Within a phase, batch related questions into one round; **never batch across phases.**
- **Every question must earn its place:** ask only when the answer (a) isn't determinable from code _and_ (b) changes the plan in a way you can't sensibly default. If you could pick a reasonable default and let the user correct it — UI surface, naming, cosmetic choices — put it in the end-state draft instead of spending a question on it.

## Phase 1 — Goal, not solution

Users arrive with a solution ("deploy on Azure") when the goal is an outcome ("N external users can run the app") that other approaches might serve better. Ask what problem the named solution solves, offering candidate goals as options; repeat until you reach an outcome that isn't itself a solution. State it solution-agnostically and confirm. If the request bundles several uses ("export images for slides _and_ to show customers"), check whether one solution serves all of them or they fork — don't let one use silently absorb the others. Stop climbing when the next "why" leaves the software/product domain (e.g. "so the business makes money") or the user confirms you've captured their intent.

## Phase 2 — Pin the end-state

Offer 2–3 viable approaches with their tradeoffs (effort, risk, reversibility, fit) and let the user choose — don't default to the one they named. A real multi-axis comparison goes in prose or a table alongside the question; a simple pick can live in the option labels.

Then make the end-state specific, measurable, and recognizable on arrival. Reflect back a draft (including any defaulted cosmetic/surface choices), refine, confirm. Always pin: what "done" means; dependents; hard constraints (stay deployable? stable public API?); success metric where applicable; what's out of scope. Then by type:

- **Feature:** the new capability; acceptance criteria + edge cases; non-functional needs (latency, scale, security); rollout (flag → internal → GA).
- **Refactor:** target structure (boundaries, dependency direction, what's deleted); behavior preserved, and _how that's verified_ (existing or characterization tests).
- **Migration/upgrade:** source→target; cutover style (parallel-run, phased, big-bang); data and compatibility; rollback.

If the target can't be pinned because its feasibility is unknown (e.g. "can we hit p99 < 50ms?"), don't guess — make the first milestone a spike to resolve it, then return and set the now-knowable end-state. (A vaguely _worded_ target just needs sharpening here; this exception is only for targets genuinely undiscoverable until some work is done.)

## Phase 3 — Backcast

A loop, not a forward pass. Start from the baseline (where the code honestly is) and the gap to the end-state.

**Reverse-chain (core move):** from the end-state, repeatedly ask **"what must be true immediately before this?"** Write each answer as a prior milestone phrased as a _system state, not a task_ ("all callers on new API, old deleted", not "delete old API"). Chain back to today, branching where milestones are independent.

Asking that question _is_ the feasibility test. When the honest answer is risky, classify and act (a precondition can be more than one):

- **infeasible** — can't be made true → revise the end-state; loop back to Phase 2.
- **unknown** — can't tell without investigating → resolve with a spike before planning on top of it.
- **irreversible** — no way back → isolate to one rehearsed step with tested rollback and a leading indicator.
- **linchpin** — many milestones depend on it → validate early.

Keep every milestone shippable and green (deployable, tests passing, reversible). Decompose with expand-contract, branch by abstraction, strangler fig, characterization-tests-first, or feature flags. Pin legacy behavior in tests before touching it, and never combine a refactor with a behavior change in one milestone.

**Flip to a roadmap:** reverse the chain into now→end-state, sequence it, mark each milestone's dependencies, and identify the critical path (longest chain of dependent milestones). **First moves:** turn the earliest milestones into concrete actions, prioritized by leverage and option-value — usually characterization tests, introducing a seam, or spiking the riskiest unknown.

## Output

```
# Plan: [goal]
## Goal                   solution-agnostic outcome
## Approach (chosen)      plus why over the alternatives
## End-state (agreed)     specific, measurable; for a refactor, the behavior-check
## Where the code is now  honest baseline + gap
## Backward chain         critical path only: [end] ← [state] ← ... ← [today]
## Roadmap                M1 [shippable state], deps: none; M2 ..., deps: M1
                          Critical path: M1 → M3 → M6
## First moves            [action], why high-leverage / no-regret
## Risks & checkpoints    [risk, classified], watch: [indicator], rollback: [Y], revisit when: [trigger]
```

For small or already-scoped tasks the _written plan_ can collapse to: goal, end-state, backward chain, first moves — output length only; this never licenses merging phases or skipping a confirmation.
