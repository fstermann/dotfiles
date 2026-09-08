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

### Implement a reviewer's suggestion (your PR)

You reply to the comment with `/implement`. On the next `/review-pr` Claude edits the code, commits, pushes, and rewrites your reply in place, citing the sha.

<img src="assets/own-implement-before.svg" width="720" alt="Reviewer asks to avoid the O(n) scan; you reply /implement use a Set">

<sub><i>run</i> <code>/review-pr</code> ↓</sub>

<img src="assets/own-implement-after.svg" width="720" alt="Your reply is rewritten to: Done in a1b2c3, switched to a Set">

### Follow up without re-tagging (your PR)

In a thread you already tagged, just keep talking, no directive needed. Claude infers intent: a question gets answered, a needed change gets made. (A thread you never tagged is left for the reviewer.)

<img src="assets/own-followup-before.svg" width="720" alt="Below the resolved reply you add: ok but what about the empty input case?">

<sub><i>run</i> <code>/review-pr</code> ↓</sub>

<img src="assets/own-followup-after.svg" width="720" alt="The follow-up is inferred as a change and rewritten: empty input now returns early, Done in d4e5f6">

### Review someone else's PR

Claude drafts pending comments; you sharpen one with `/ask`. It writes its finding into a scratchpad under your comment. Everything stays **Pending** until you submit; `/reply` later turns the scratchpad into the clean comment.

<img src="assets/review-ask-before.svg" width="720" alt="Your pending comment asks if it is a race and tags /ask to check the mutex">

<sub><i>run</i> <code>/review-pr</code> ↓</sub>

<img src="assets/review-ask-after.svg" width="720" alt="Claude appends a scratchpad confirming the race and suggesting a fix, still Pending">

Other directives work the same way: `/reply` on your PR answers a reviewer with no code change, and your own review notes get fixed and marked ✅ / 💬 / ⚠️ / ❓ (see above).
