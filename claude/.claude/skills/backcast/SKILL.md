---
name: backcast
description: Use when the user wants a plan to get from today's codebase to a substantially different end-state, especially when that destination is fuzzy or stated as a solution rather than an outcome. Covers refactors, migrations, re-architectures, rewrites, and large multi-step features. Trigger on "help me plan/scope this", "how should I approach", "what's the roadmap for", or a named solution ("migrate to X", "rebuild as Y") whose underlying goal is unstated. Skip single decisions, one-step changes, and plans that are already concrete.
---

Plan backward from the end-state, not forward from today's code. Forward planning drifts into local-optimum incrementalism — each step looks fine alone, the destination is never reckoned with, and the plan inherits the current code's shape. Fix the target first, then derive only the steps that reach it.

Three phases, **strictly in order**: define the goal → pin the end-state → backcast the plan. Each is iterative — keep asking within it until the user confirms, then move on. Never ask a later phase's questions before the current one is confirmed (a Phase 2 question about format or structure presupposes the goal Phase 1 exists to settle). Extra rounds are fine; never merge or skip phases to save a turn.

Throughout:

- **Read before asking.** Determine from code, tests, configs, and deps anything you can; don't ask what the code can tell you.
- **Ask via `AskUserQuestion`** with concrete options; free-form only when options won't fit. Batch related questions within a phase; **never batch across phases.**
- **Every question must earn its place:** ask only when the answer (a) isn't determinable from code *and* (b) changes the plan in a way you can't sensibly default. If you could pick a reasonable default and let the user correct it (UI surface, naming, cosmetics), put it in the end-state draft instead.

## Phase 1 — Goal, not solution

Users arrive with a solution ("deploy on Azure") when the goal is an outcome ("N external users can run the app") that other approaches might serve better. Ask what problem the named solution solves, offering candidate goals as options; repeat until you reach an outcome that isn't itself a solution. State it solution-agnostically and confirm. If the request bundles several uses, check whether one solution serves all or they fork — don't let one use silently absorb the others. Stop climbing when the next "why" leaves the software/product domain, or the user confirms you've captured their intent.

## Phase 2 — Pin the end-state

Offer 2–3 viable approaches with tradeoffs (effort, risk, reversibility, fit) and let the user choose — don't default to the one they named. Put a real multi-axis comparison in prose or a table alongside the question; a simple pick can live in the option labels.

Then make the end-state specific, measurable, and recognizable on arrival. Reflect back a draft (including any defaulted cosmetic choices), refine, confirm. Always pin: what "done" means; dependents; hard constraints (stay deployable? stable public API?); success metric where applicable; what's out of scope. Then by type:

- **Feature:** the new capability; acceptance criteria + edge cases; non-functional needs (latency, scale, security); rollout (flag → internal → GA).
- **Refactor:** target structure (boundaries, dependency direction, what's deleted); behavior preserved, and *how that's verified* (existing or characterization tests).
- **Migration/upgrade:** source→target; cutover style (parallel-run, phased, big-bang); data and compatibility; rollback.

If the target can't be pinned because feasibility is unknown ("can we hit p99 < 50ms?"), don't guess — make the first milestone a spike to resolve it, then set the now-knowable end-state. (A vaguely *worded* target just needs sharpening; this exception is only for targets genuinely undiscoverable until some work is done.)

## Phase 3 — Backcast

A loop, not a forward pass. Start from the baseline (where the code honestly is) and the gap to the end-state.

**Reverse-chain (core move):** from the end-state, repeatedly ask **"what must be true immediately before this?"** Write each answer as a prior milestone phrased as a *system state, not a task* ("all callers on new API, old deleted", not "delete old API"). Chain back to today, branching where milestones are independent.

Asking that question *is* the feasibility test. When the honest answer is risky, classify and act (a precondition can be more than one):

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

For small or already-scoped tasks the *written plan* can collapse to: goal, end-state, backward chain, first moves — output length only; this never licenses merging phases or skipping a confirmation.
