---
name: review-pr
description: Invoke only via the /review-pr command, never automatically. Review a PR with me. Three modes, auto-detected by who authored the PR. Fix (my PR, my own comments) fixes/refactors the code. Review (someone else's PR) writes a pending review where needed and sharpens/answers pending comments in-thread. Respond (reviewers commented on my PR) implements or answers their feedback via inline directives and drafts my brief reply.
---

Review a PR with me. Resolve the PR, pick the mode from who authored it, then act on comments.

Deterministic steps are scripts in `scripts/` (run from `$HOME/.claude/skills/review-pr/scripts`); judgment steps are prose. Never submit a review or resolve a thread; only I do that.

## Step 1: Resolve and pick the mode

```bash
S="$HOME/.claude/skills/review-pr/scripts"
"$S/resolve-pr.sh" "$REF"     # $REF: number, URL, or omit for current branch's PR
# Multi-repo workspace (cwd isn't the target repo): pass --repo owner/name with a PR number.
```

Returns `{owner,repo,num,me,author,mode,url,headRef,currentBranch,dirty}`.

- `mode:"reviewing"` (author != me) → **Review mode** (Step 3R).
- `mode:"own"` (author == me) → **Fix mode** for my own comments and **Respond mode** for reviewers' comments, decided per comment (Step 3F).
- `dirty:true` with unrelated changes → stop; don't mix them into feedback commits.
- `currentBranch != headRef` and you'll edit code → `gh pr checkout <num>`.

## Fence convention

In Review and Respond mode you answer by rewriting a comment body (`edit-comment.sh`), not by posting marker replies. In Review mode your working contributions are fenced so they're idempotent and strippable:

```
<my original text>

---
<!-- claude:start -->
<your answer>
<!-- claude:end -->
```

Re-running replaces the fenced block (and its `---` divider), never stacks. Finalize strips the fence entirely.

## Directives (AIR)

I write these inline in a comment to tell you what to do. Long or short form; `fetch-*` normalizes to the long name in the `directive` field.

| Directive | Short | Mode | Action |
| --------- | ----- | ---- | ------ |
| `/ask [ctx]` | `/a` | Review | Engage: verify a claim, suggest, or research → fenced scratchpad |
| `/implement [ctx]` | `/i` | Respond | Change the code, then write my brief reply |
| `/reply [ctx]` | `/r` | Review + Respond | Produce the clean final text (strip scratchpad) |

`/ask` and `/implement` ask for work; `/reply` writes the final message. Untagged comments are left alone.

---

## Step 3R: Review mode (I'm reviewing someone else's PR)

Two things happen here, both leaving everything **pending** so I review and submit myself. Never submit my review.

**Initial review (when I ask you to review the PR).** Read the diff (`gh pr diff <num>`), find real issues, and write draft comments where warranted. Comment only where it earns it; no nitpick padding. Create them as one pending review:

```bash
echo '[{"path":"src/a.ts","line":42,"body":"..."},{"path":"src/b.ts","line":10,"body":"..."}]' \
  | "$S/create-pending-review.sh" <owner> <repo> <num>
```

These land as pending comments. From here they're normal pending comments: I review your review, add my own, and we sharpen them together below. (Fails if I already have a pending review on the PR; in that case add nothing and just sharpen what's there.)

**Sharpen (my draft review, or yours).** I write or edit pending comments; you sharpen and answer each in-thread.

```bash
"$S/fetch-comments.sh" <owner> <repo> <num> <me>
```

Use the `source:"pending"` rows (my draft review). Each carries `node_id`, `has_fence`, `directive`, `reply_to`. Act only on comments I tagged; leave the rest untouched.

**Fold my replies first.** For any pending row with `reply_to` pointing at another of my pending comments (a separate draft reply I added), merge its text into that parent comment, then delete the reply:

```bash
"$S/delete-comment.sh" <reply_node_id>
```

Auto-fold, no confirmation. One comment per thread is the goal.

**Engage the ones I tagged `/ask` (`/a`).** For rows with `directive:"ask"`, read the code (`path`+`line`, `diff_hunk`) and do what I asked:

- Verify a claim I made → say whether it holds against the code.
- Draft a concrete suggestion or code.
- Research X → answer inline.
- My comment is weak or wrong → say so; propose a sharper one or suggest dropping it.

Write the answer into the same comment via the fence convention. If `has_fence`, replace the existing block:

```bash
"$S/edit-comment.sh" <node_id> "$BODY"   # BODY = <my text>\n\n---\n<!-- claude:start -->\n<answer>\n<!-- claude:end -->
```

**Finalize with `/reply` (`/r`).** When a comment's `directive` is `reply`, stop iterating on it: compose one clean comment addressed to the PR author from my text + our scratchpad, and set the body to only that (no fence, no divider, no `/reply` line):

```bash
"$S/edit-comment.sh" <node_id> "$FINAL"
```

After finalize the comment is submit-ready. I submit the review myself.

---

## Step 3F: Fix + Respond mode (my PR)

```bash
"$S/fetch-comments.sh" <owner> <repo> <num> <me>            # my own comments  → Fix
"$S/fetch-reviewer-comments.sh" <owner> <repo> <num> <me>   # reviewers' comments → Respond
```

### Fix: my own comments

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
"$S/post-reply.sh" review  <owner> <repo> <num> <comment_id> "✅ Renamed \`x\`→\`userId\` in <sha>."
"$S/post-reply.sh" issue   <owner> <repo> <num> <comment_id> "💬 Retry is in client.ts:30."
"$S/post-reply.sh" pending <thread_id> <review_id> <comment_id> "✅ Addressed in <sha>."
```

Hold the reply for any ❓ until I answer. The script appends the idempotency marker.

### Respond: reviewers' comments, directive-driven

`fetch-reviewer-comments.sh` returns one row per unresolved thread's top-level reviewer comment, with `directive` and `directive_node_id` from my latest reply in that thread. Act only on rows where I left a directive; list the rest, don't touch them.

- `directive:"implement"` (`/implement` / `/i`) → implement the reviewer's feedback, using my context. Commit as in Fix. Then rewrite my directive comment into a brief reply describing what was done:

  ```bash
  git push
  "$S/edit-comment.sh" <directive_node_id> "Done in <sha>: <one line>."
  ```

- `directive:"reply"` (`/reply` / `/r`) → research or suggest as I asked, no code change, then rewrite my directive comment into a brief reply to the reviewer:

  ```bash
  "$S/edit-comment.sh" <directive_node_id> "<brief answer>."
  ```

- `directive:null` → list the comment so I can triage. Don't act.
- A question I asked the reviewer (my reply, no directive) → leave untouched.

Keep replies very brief. These replace my directive text, so the reviewer sees only the clean answer.

---

## Step 4: Summarize

Print a table of what you did, then list every ❓ and ⚠️ in full. In Review mode, list which comments are now finalized vs still in scratchpad. Report SHAs pushed, comments edited or replied to, and anything still needing me.

## Notes

- "My comments" / "me" = the authenticated `gh` user.
- Fix and Respond can both appear on the same PR (my comments + reviewers'); handle each comment by its author.
- `edit-comment.sh` and `delete-comment.sh` work on pending and published comments; they never submit the review.
- Folding deletes my own draft replies (auto). Everything else that removes my content waits for me.
- If I say don't push on a run, stop after the summary and commits.
