---
name: pr-feedback
description: Address my review comments on a pull request. Fetches published, pending, and general comments on a PR (by number, URL, or the current branch's PR), then for each one either fixes the code or answers it, marks each with a status emoji, commits, pushes, and posts a reply to each comment (published reply for published comments, draft reply for pending ones). Trigger on "address my PR comments", "review my PR feedback", "handle the comments on PR #N", or a PR ref plus "address the comments".
---

For each of my review comments on a PR: fix the code or answer it, tag it with a status emoji, report in the session, and reply on GitHub (published reply for published comments, draft reply for pending ones).

Deterministic steps are scripts in `scripts/` (run from `$HOME/.claude/skills/pr-feedback/scripts`); judgment steps are prose.

## Status emojis

| Emoji | Meaning                                                    |
| ----- | ---------------------------------------------------------- |
| ✅    | Fixed in code (cite the commit) or question answered fully |
| 💬    | Answered — no code change needed                           |
| ⚠️    | Partial or not straightforward — explain why               |
| ❓    | Needs your input before I proceed                          |

## Step 1 — Resolve the PR

```bash
S="$HOME/.claude/skills/pr-feedback/scripts"
"$S/resolve-pr.sh" "$REF"     # $REF: number, URL, or omit for current branch's PR
```

Returns `{owner,repo,num,me,url,headRef,currentBranch,dirty}`. Then:

- `dirty:true` with unrelated changes → stop; don't mix them into feedback commits.
- `currentBranch != headRef` → `gh pr checkout <num>`.

## Step 2 — Fetch the comments

```bash
"$S/fetch-comments.sh" <owner> <repo> <num> <me>
```

Returns my top-level comments as JSON: `[{id, source, path, line, body, diff_hunk, url, thread_id, review_id}]`. Already-answered ones (a reply whose marker cites their id) are dropped.

- `source: review` → published inline; reply is a published thread reply.
- `source: issue` → general conversation comment; reply is a new published conversation comment.
- `source: pending` → my draft review (via GraphQL; carries `thread_id` + `review_id`); reply goes in as a **draft** and stays pending until I submit. Never submit my review for me.

## Step 3 — Address each comment

Read the referenced code (`path` + `line`, `diff_hunk` for context), then pick one:

- Clear and actionable → make the minimal edit (surgical, match style, nothing speculative). → ✅
- Question answerable from the code → answer, no edit. → 💬
- Real caveat or bigger than it looks → do what's safe, explain the rest. → ⚠️
- Needs my decision → don't guess; write the specific question. → ❓

One or two sentences per note. One commit per addressed comment so each ✅ cites its SHA:

```
fix(review): <short summary>

Addresses PR #<num> comment on <path>:<line>
```

## Step 4 — Summarize

Print the table, then list every ❓ and ⚠️ in full:

```
PR #<num> — <title>

┌─────────────────────────────┬────┬───────────────────────────┐
│ Comment (path:line)         │ St │ Action                    │
├─────────────────────────────┼────┼───────────────────────────┤
│ auth.ts:42 rename var       │ ✅ │ renamed x→userId          │
│ api.ts:88 why no retry?     │ 💬 │ retry is in client.ts:30  │
│ cache.ts:5 memoize this     │ ⚠️ │ needs invalidation design │
│ db.ts:12 add index?         │ ❓ │ which column?             │
└─────────────────────────────┴────┴───────────────────────────┘
```

Then proceed straight to Step 5 — no confirmation needed. Hold the reply for any ❓ item until I answer it; push and reply to the rest.

## Step 5 — Push and reply

```bash
git push
# published inline / conversation → public reply:
"$S/post-reply.sh" review  <owner> <repo> <num> <comment_id> "✅ Renamed \`x\`→\`userId\` in <sha>."
"$S/post-reply.sh" issue   <owner> <repo> <num> <comment_id> "💬 Retry is handled in client.ts:30."
# pending → draft reply, stays in my review until I submit:
"$S/post-reply.sh" pending <thread_id> <review_id> <comment_id> "✅ Addressed in <sha>."
```

The script appends the marker. Pending replies stay pending (not public); the push and any `review`/`issue` replies are the public part. Report SHAs pushed, comments replied to, and anything still needing me.

## Notes

- "My comments" = comments by the authenticated `gh` user (I usually author and self-review the PR).
- The skill never resolves threads or submits reviews — only I do that.
- If I say don't push on a run, stop after the summary and commits.
