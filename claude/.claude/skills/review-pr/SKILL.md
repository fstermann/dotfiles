---
name: review-pr
description: Invoke only via the /review-pr command, never automatically. Review a PR with me. Two flows, auto-detected by who authored the PR. On my own PR, fix the code for my own comments and respond to reviewers' comments via inline directives. On someone else's PR, write a pending review and sharpen or answer pending comments in-thread. I submit every review and resolve every thread myself.
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

In the Reviewing flow, and when responding to reviewers, I answer by rewriting a comment body (`edit-comment.sh`), not by posting marker replies. Your scratchpad goes in a fence so it's idempotent and strippable:

```
<my original text>

---
<!-- claude:start -->
<your scratchpad>
<!-- claude:end -->
```

Re-running replaces the scratchpad (and its `---` divider), never stacks. `/reply` strips the fence entirely.

### Directives (AIR)

I write these inline in a comment to tell you what to do. Long or short form; `fetch-*` normalizes to the long name in the `directive` field.

| Directive | Short | Flow | Action |
| --------- | ----- | ---- | ------ |
| `/ask [ctx]` | `/a` | Reviewing | Act: verify a claim, suggest, or research → scratchpad |
| `/implement [ctx]` | `/i` | Own PR | Change the code, then write my brief reply |
| `/reply [ctx]` | `/r` | both | Produce the final reply (Reviewing: strip the scratchpad; Own PR: compose the reply to the reviewer) |

`/ask` and `/implement` ask for work; `/reply` produces the final reply. A comment I never tagged is left alone, but a follow-up I add to a thread I already tagged is picked up next run: Reviewing folds it into the parent and re-engages the `/ask`; Own PR infers intent (see Respond).

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

**Fold my replies first.** For any pending row with `reply_to` pointing at another of my pending comments (a separate reply I added), merge its text into that parent comment, then delete the reply:

```bash
"$S/delete-comment.sh" <reply_node_id>
```

Auto-fold, no confirmation. One comment per thread is the goal.

**Act on the ones I tagged `/ask` (`/a`).** For rows with `directive:"ask"`, read the code (`path`+`line`, `diff_hunk`) and do what I asked:

- Verify a claim I made → say whether it holds against the code.
- Draft a concrete suggestion or code.
- Research X → answer inline.
- My comment is weak or wrong → say so; propose a sharper one or suggest dropping it.

Write the scratchpad into the same comment via the fence. If `has_fence`, replace the existing scratchpad:

```bash
"$S/edit-comment.sh" <node_id> "$BODY"   # BODY = <my text>\n\n---\n<!-- claude:start -->\n<scratchpad>\n<!-- claude:end -->
```

**Finalize with `/reply` (`/r`).** When a comment's `directive` is `reply`, stop iterating on it: compose one clean reply to the PR author from my text + the scratchpad, and set the body to only that (no fence, no divider, no `/reply` line):

```bash
"$S/edit-comment.sh" <node_id> "$FINAL"
```

After finalize the comment is submit-ready.

### Own PR (fix my own comments, respond to reviewers')

```bash
"$S/fetch-comments.sh" <owner> <repo> <num> <me>            # my own comments      → Fix
"$S/fetch-reviewer-comments.sh" <owner> <repo> <num> <me>   # reviewers' comments  → Respond
```

Route each comment by its author: my own → Fix, a reviewer's → Respond.

#### Fix: my own comments

Status emojis:

| Emoji | Meaning |
| ----- | ------- |
| ✅ | Fixed in code (cite the commit) or answered fully |
| 💬 | Answered, no code change |
| ⚠️ | Partial or not straightforward, explain why |
| ❓ | Needs my input first |

Read the code, then pick: clear+actionable → minimal edit (surgical, match style) → ✅; question answerable from code → 💬; real caveat → do what's safe, explain → ⚠️; needs my decision → ❓. One or two sentences each. One commit per addressed comment:

```
fix(review): <short summary>

Addresses PR #<num> comment on <path>:<line>
```

Reply after pushing:

```bash
git push
"$S/post-comment.sh" review  <owner> <repo> <num> <comment_id> "✅ Renamed \`x\`→\`userId\` in <sha>."
"$S/post-comment.sh" issue   <owner> <repo> <num> <comment_id> "💬 Retry is in client.ts:30."
"$S/post-comment.sh" pending <thread_id> <review_id> <comment_id> "✅ Addressed in <sha>."
```

Hold the reply for any ❓ until I answer. The script appends the idempotency marker.

#### Respond: reviewers' comments, directive-driven

`fetch-reviewer-comments.sh` returns one row per unresolved thread's top-level reviewer comment, with `directive` and `directive_node_id` from my latest comment in that thread. Act only where `directive` is non-null; list the rest, don't touch them. Every rewrite passes the row's `id` as the third arg so the final carries the `claude:reply` marker and the next run skips it, no loop.

- `directive:"implement"` (`/implement` / `/i`) → implement the reviewer's feedback, using my context. Commit as in Fix. Then rewrite my directive comment into a brief reply describing what was done:

  ```bash
  git push
  "$S/edit-comment.sh" <directive_node_id> "Done in <sha>: <one line>." <id>
  ```

- `directive:"reply"` (`/reply` / `/r`) → research or suggest as I asked, no code change, then rewrite my directive comment into a brief reply to the reviewer:

  ```bash
  "$S/edit-comment.sh" <directive_node_id> "<brief reply>." <id>
  ```

- `directive:"infer"` → an untagged follow-up I added to a thread I already tagged. Infer intent from my text: only a clarification → do the `reply` case; a change is needed → do the `implement` case. Either way, rewrite `<directive_node_id>` and stamp `<id>`.
- `directive:null` → I never tagged this thread (or I'm talking to the reviewer). List it so I can triage; don't act.

Keep replies very brief. These replace my directive text, so the reviewer sees only the clean reply.

---

## Step 4: Summarize

Print a table of what you did, then list every ❓ and ⚠️ in full. In the Reviewing flow, list which comments are now finalized vs still in scratchpad. Report SHAs pushed, comments edited or replied to, and anything still needing me.

## Notes

- "My comments" / "me" = the authenticated `gh` user.
- On my own PR, my comments (Fix) and reviewers' comments (Respond) both appear; route each by its author.
- `edit-comment.sh` and `delete-comment.sh` work on pending and published comments; they never submit the review.
- Folding deletes my own pending replies (auto). Everything else that removes my content waits for me.
- If I say don't push on a run, stop after the summary and commits.
