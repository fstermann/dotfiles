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

## Example

On your PR, reply to a reviewer's comment:

```
/implement use a Set here instead of the array scan
```

Next `/review-pr`: Claude makes the change, commits, pushes, and rewrites your comment to something like `Done in a1b2c3: switched to a Set.`
