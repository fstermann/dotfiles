# review-pr

Work a GitHub PR's comments with Claude. You stay in control: Claude edits code, drafts comments, and writes replies, but never submits a review or resolves a thread. You do that.

## Run it

```
/review-pr            # the current branch's PR
/review-pr 123        # by number
/review-pr <url>      # by URL
```

Runs only when you invoke it, never on its own. In a multi-repo workspace, add `--repo owner/name` with a number.

## Two flows, auto-detected by who authored the PR

**Your PR.** Each comment is handled by who wrote it:
- Your own comments → Claude fixes the code (one commit each) and replies with a status emoji: ✅ fixed, 💬 answered, ⚠️ partial, ❓ needs your input.
- Reviewers' comments → Claude acts on the directive you left (below) and rewrites your directive into the clean reply the reviewer sees.

**Someone else's PR.** Claude drafts a pending review where warranted, then sharpens and answers your pending comments in place. Everything stays pending; you read it and submit.

## Directives (AIR)

Write one inline in a comment to tell Claude what to do. Long or short form.

| Directive | Short | Where | Does |
| --------- | ----- | ----- | ---- |
| `/ask` | `/a` | reviewing a PR | verify a claim, suggest, or research into a scratchpad |
| `/implement` | `/i` | your PR | apply the reviewer's feedback in code |
| `/reply` | `/r` | either | finalize: produce the clean reply, strip the scratchpad |

A comment you never tag is left alone. A follow-up you add to a thread you already tagged is picked up on the next run: reviewing, it continues the scratchpad; on your PR, Claude infers whether it's a clarification (answers) or a change (implements).

## Examples

**Fix your own notes (your PR).** Leave comments on your own PR lines, then run `/review-pr`. Claude edits the clear ones and replies `✅ ... in <sha>`, answers from the code with `💬`, flags a real caveat with `⚠️`, and leaves anything needing your call as `❓`.

**Implement a reviewer's suggestion (your PR).** Reply to their comment:

```
/implement use a Set here instead of the array scan
```

Next `/review-pr`: Claude changes the code, commits, pushes, and rewrites your comment to `Done in a1b2c3: switched to a Set.`

**Answer a reviewer, no code change (your PR).**

```
/reply explain why we retry twice
```

Claude researches and rewrites your comment into a short reply to the reviewer. No commit.

**Follow up without re-tagging (your PR).** After the `/implement` above, you reply in the same thread, no directive:

```
ok but what about the empty input case?
```

Next run: Claude infers a change is needed, implements it, and replies. In a thread you already tagged, a question gets answered and a change gets made, either way; a thread you never tagged is left for the reviewer.

**Review someone else's PR.** `/review-pr 456`, ask Claude to review it, and it writes draft comments as one pending review. Sharpen one:

```
/ask is this actually a race, or is the lock held here?
```

Claude checks the code and writes its finding into a scratchpad under your comment. Iterate, then finalize with `/reply`. Nothing is submitted; you review the batch and submit it yourself.
