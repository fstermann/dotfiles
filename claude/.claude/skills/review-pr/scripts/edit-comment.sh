#!/usr/bin/env bash
# Rewrite a review comment's body (pending or published) via GraphQL.
# Used for scratchpad answers, folding replies, and /reply finalize.
# Usage: edit-comment.sh NODE_ID BODY [MARK_ID]
#   NODE_ID: the comment's GraphQL node id (fetch-comments.sh field `node_id`).
#   MARK_ID: optional. Appends the claude:reply marker citing this id, so the
#     next fetch skips the rewritten comment (Respond finals; the fence handles
#     idempotency for Reviewing scratchpads, so omit it there).
# Prints the comment URL.
set -euo pipefail
ID=$1 BODY=$2 MARK_ID="${3:-}"
[ -n "$MARK_ID" ] && BODY="$(printf '%s\n\n<!-- claude:reply id=%s -->' "$BODY" "$MARK_ID")"
gh api graphql -f id="$ID" -f body="$BODY" -f query='
  mutation($id:ID!,$body:String!){
    updatePullRequestReviewComment(input:{pullRequestReviewCommentId:$id, body:$body}){
      pullRequestReviewComment{ url }
    }
  }' --jq '.data.updatePullRequestReviewComment.pullRequestReviewComment.url'
