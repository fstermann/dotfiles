---
name: review-pr
description: Invoke via the /review-pr command. Review a PR with me, then keep addressing my follow-ups automatically via a background watcher until the PR closes. Two flows, auto-detected by who authored the PR. On my own PR, fix the code for my own comments (auto-push) and respond to reviewers' comments via inline directives. On someone else's PR, write a pending review and sharpen or answer pending comments in-thread. I submit every review and resolve every thread myself.
---

Review a PR with me. Resolve the ref, pick the flow from who authored the PR, then act on comments.

Deterministic steps are scripts in `scripts/` (run from `$HOME/.claude/skills/review-pr/scripts`); judgment steps are prose. Never submit a review or resolve a thread; only I do that.

## Step 1: Resolve the ref and pick the flow

```bash
S="$HOME/.claude/skills/review-pr/scripts"
"$S/resolve-ref.sh" "$REF"     # $REF: number, URL, or omit for current branch's PR
# Multi-repo workspace (cwd isn't the target repo): pass --repo owner/name with a PR number.
```

Returns `{owner,repo,num,me,author,flow,url,headRef,currentBranch,dirty}`.

- `flow:"reviewing"` (author != me) → **Reviewing flow** (Step 3, Reviewing).
- `flow:"own"` (author == me) → **Own-PR flow** (Step 3, Own PR): fix my own comments, respond to reviewers' comments, decided per comment by who wrote it.
- `dirty:true` with unrelated changes → stop; don't mix them into feedback commits.
- `currentBranch != headRef` and you'll edit code → `gh pr checkout <num>`.

## Step 2: Conventions

### Fence

In the Reviewing flow I answer by rewriting one comment body (`edit-comment.sh`) instead of posting separate replies, so the whole exchange lives in a single comment. That body is a running **transcript**: my turns and your turns alternate, each separated by a `---` divider, and each of your turns is wrapped in a fence so it's identifiable and strippable.

```
<turn 1: my comment, verbatim>

---
<!-- claude:start -->
❊ <turn 2: your answer>
<!-- claude:end -->

---
<turn 3: my follow-up, verbatim>

---
<!-- claude:start -->
❊ <turn 4: your answer>
<!-- claude:end -->
```

Rules:

- **Append, never replace or summarize.** Every earlier turn stays byte-for-byte, mine and yours; that transcript is the history. Each run adds at most one new fenced turn.
- **Answer only the last unanswered turn.** If the body already ends in your fenced answer, there's nothing to do (idempotent, no duplicate turns). Add a turn only when my text is the last block.
- **My turns stay verbatim,** directive line and all. Only `/reply` collapses the transcript into one clean comment and strips the fences, dividers, and directive line.
- **Your turns lead with `❊`,** the answered glyph, so a reader spots your voice in the transcript even though the fence markers are invisible.

### Directives (AIR)

I write these inline in a comment to tell you what to do. Long or short form; `fetch-*` normalizes to the long name in the `directive` field.

| Directive | Short | Flow | Action |
| --------- | ----- | ---- | ------ |
| `/ask [ctx]` | `/a` | Reviewing | Answer: verify a claim, suggest, or research → a new transcript turn |
| `/implement [ctx]` | `/i` | Own PR | Change the code, then write my brief reply |
| `/reply [ctx]` | `/r` | both | Produce the final reply (Reviewing: collapse the transcript; Own PR: compose the reply to the reviewer) |

`/ask` and `/implement` ask for work; `/reply` produces the final reply. A comment I never tagged is left alone, but a follow-up I add to a thread I already tagged is picked up next run: Reviewing folds it in as the next transcript turn and answers it; Own PR infers intent (see Respond).

---

## Step 3: Act on comments

### Reviewing (someone else's PR)

Two things happen here, both left **pending** so I review and submit myself.

**Initial review (when I ask you to review the PR).** Read the diff (`gh pr diff <num>`), find real issues, and write pending comments where warranted. Comment only where it earns it; no nitpick padding. Create them as one pending review:

```bash
echo '[{"path":"src/a.ts","line":42,"body":"..."},{"path":"src/b.ts","line":10,"body":"..."}]' \
  | "$S/create-pending-review.sh" <owner> <repo> <num>
```

From here they're normal pending comments: I review your review, add my own, and we sharpen them together below. (Fails if I already have a pending review on the PR; in that case add nothing and just sharpen what's there.)

**Sharpen (my pending comments, or yours).** I write or edit pending comments; you sharpen and answer each in-thread.

```bash
"$S/fetch-comments.sh" <owner> <repo> <num> <me>
```

Use the `source:"pending"` rows. Each carries `node_id`, `has_fence`, `directive`, `reply_to`. Act only on comments I tagged; leave the rest untouched.

**Fold my follow-ups first.** If I commented again in the thread (a pending row whose `reply_to` points at another of my pending comments, whether I used Reply or just typed a fresh comment on the line), append its text to that parent's transcript as the next "me" turn, preceded by a `---` divider, then delete the separate reply:

```bash
"$S/delete-comment.sh" <reply_node_id>
```

Auto-fold, no confirmation. One comment per thread is the goal: the parent holds the whole conversation.

**Answer the ones I tagged `/ask` (`/a`).** For rows with `directive:"ask"`, read the code (`path`+`line`, `diff_hunk`) and do what I asked:

- Verify a claim I made → say whether it holds against the code.
- Draft a concrete suggestion or code.
- Research X → answer inline.
- My comment is weak or wrong → say so; propose a sharper one or suggest dropping it.

Append your answer as a new fenced turn at the end of the transcript, per the fence rules: every earlier turn stays verbatim, and you answer only the last unanswered turn of mine (if the body already ends in a fenced answer, skip it).

```bash
"$S/edit-comment.sh" <node_id> "$BODY"   # BODY = <transcript so far>\n\n---\n<!-- claude:start -->\n❊ <answer>\n<!-- claude:end -->
```

**Finalize with `/reply` (`/r`).** When a comment's `directive` is `reply`, stop iterating and collapse the whole transcript into one clean comment, then set the body to only that (no fences, no dividers, no `/reply` line). The collapse deletes my questions, so write for what survives: a single comment on a code line. Fit it to that context instead of answering the last turn. If I opened the thread, it's a review remark about the code; if a colleague did, it answers them. Either way self-contained and led with the `❊` glyph:

```bash
"$S/edit-comment.sh" <node_id> "❊ $FINAL"
```

After finalize the comment is submit-ready.

### Own PR (fix my own comments, respond to reviewers')

```bash
"$S/fetch-comments.sh" <owner> <repo> <num> <me>            # my own comments      → Fix
"$S/fetch-reviewer-comments.sh" <owner> <repo> <num> <me>   # reviewers' comments  → Respond
```

Route each comment by its author: my own → Fix, a reviewer's → Respond.

#### Fix: my own comments

Status glyphs (monochrome, so they read as a quiet marker, not decoration):

| Glyph | Meaning |
| ----- | ------- |
| ● | Fixed in code (cite the commit) |
| ❊ | Answered, no code change |
| ◐ | Partial or not straightforward, explain why |
| ○ | Needs my input first |

`●◐○` track code state; `❊` is Claude's voice (same glyph marks a `/reply` finalize, below). Read the code, then pick: clear+actionable → minimal edit (surgical, match style) → ●; question answerable from code → ❊; real caveat → do what's safe, explain → ◐; needs my decision → ○. One or two sentences each. One commit per addressed comment:

```
fix(review): <short summary>

Addresses PR #<num> comment on <path>:<line>
```

Reply after pushing:

```bash
git push
"$S/post-comment.sh" review  <owner> <repo> <num> <comment_id> "● Renamed \`x\`→\`userId\` in <sha>."
"$S/post-comment.sh" issue   <owner> <repo> <num> <comment_id> "❊ Retry is in client.ts:30."
"$S/post-comment.sh" pending <thread_id> <review_id> <comment_id> "● Addressed in <sha>."
```

Post every glyph, ○ included, so I answer in the PR thread, not the session; my reply is a follow-up you pick up next run. Phrase a ○ as the question you need answered. The script appends the idempotency marker.

#### Respond: reviewers' comments, directive-driven

`fetch-reviewer-comments.sh` returns one row per unresolved thread's top-level reviewer comment, with `directive` and `directive_node_id` from my latest comment in that thread. Act only where `directive` is non-null; list the rest, don't touch them. Every rewrite passes the row's `id` as the third arg so the final carries the `claude:reply` marker and the next run skips it, no loop.

- `directive:"implement"` (`/implement` / `/i`) → implement the reviewer's feedback, using my context. Commit as in Fix. Then rewrite my directive comment into a brief reply describing what was done:

  ```bash
  git push
  "$S/edit-comment.sh" <directive_node_id> "● Done in <sha>: <one line>." <id>
  ```

- `directive:"reply"` (`/reply` / `/r`) → research or suggest as I asked, no code change, then rewrite my directive comment into a brief reply to the reviewer:

  ```bash
  "$S/edit-comment.sh" <directive_node_id> "❊ <brief reply>." <id>
  ```

- `directive:"infer"` → an untagged follow-up I added to a thread I already tagged. Infer intent from my text: only a clarification → do the `reply` case; a change is needed → do the `implement` case. Either way, rewrite `<directive_node_id>` and stamp `<id>`.
- `directive:null` → I never tagged this thread (or I'm talking to the reviewer). List it so I can triage; don't act.

Keep replies very brief and factual: state what changed and where. The reply replaces my directive text, so don't refer back to the words you're overwriting, they're gone. Match the phrasing to who raised the point: an `infer` follow-up was mine, not the reviewer's, so state what was done ("Also handled the empty input case: ...") rather than thanking or crediting them ("Good catch").

---

## Step 4: Summarize

Link the PR (`url` from `resolve-ref.sh`) on its own line, then print one table, one row per comment you acted on, whatever its glyph (● ❊ ◐ ○):

| Comment | Action |
| ------- | ------ |
| [`path:line`](comment `url`) | ● what changed, with sha if pushed |

The table is comments only, nothing about the watcher, relaunches, or session mechanics. Below it, spell out every ◐ and ○ in full (the row is one line; these need the detail), and in the Reviewing flow note which comments are finalized vs still mid-transcript. This applies to the initial run and to every watcher wake (Step 5).

## Step 5: Auto-watch (address my follow-ups without a re-invoke)

After the run, keep catching my follow-ups on their own. Launch the watcher once with the Bash tool's `run_in_background` (`me` and `flow` come from `resolve-ref.sh`):

```bash
"$S/watch-comments.sh" <owner> <repo> <num> <me> <flow>
```

It polls every 60s with `check-work.sh` (deterministic, no judgment) and exits the moment there's work, which re-invokes this session. On that wake:

1. The task output carries the actionable rows and its `flow`. Run only that Step 3 branch, on those rows only.
2. Auto-push is allowed on `/implement` and on Fix.
3. Summarize (Step 4), links included, so each wake leaves the same navigable trail as the initial run.
4. Relaunch the watcher (exactly one at a time) and stop.

Every glyph is posted (Step 3, Fix), so a `○` parks itself and never retriggers the gate; I answer it in the PR thread and that follow-up wakes you again.

The watcher stops itself in three cases; on any of them, report it and **don't** relaunch:

- **Idle timeout** (exit 2, after 30 min quiet): tell me here in the session that the watch paused and I can restart it with `/review-pr`. Nothing is posted to the PR. The idle clock resets each time work is found, so it only fires on a real quiet stretch.
- **PR closed or merged** (exit 3).
- I stop it with `TaskStop`, or tell you to.

Re-running `/review-pr` by hand spawns a second watcher, so stop the old one first. The watcher never submits a review or resolves a thread.

## Notes

- "My comments" / "me" = the authenticated `gh` user.
- On my own PR, my comments (Fix) and reviewers' comments (Respond) both appear; route each by its author.
- `edit-comment.sh` and `delete-comment.sh` work on pending and published comments; they never submit the review.
- Folding deletes my own pending replies (auto). Everything else that removes my content waits for me.
- If I say don't push on a run, stop after the summary and commits.
