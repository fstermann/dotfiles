#!/usr/bin/env bash
# Rewrite a review comment's body (pending or published) via GraphQL.
# Used for scratchpad answers, folding replies, and /answer finalize.
# Usage: edit-comment.sh NODE_ID BODY
#   NODE_ID: the comment's GraphQL node id (fetch-comments.sh field `node_id`).
# Prints the comment URL.
set -euo pipefail
ID=$1 BODY=$2
gh api graphql -f id="$ID" -f body="$BODY" -f query='
  mutation($id:ID!,$body:String!){
    updatePullRequestReviewComment(input:{pullRequestReviewCommentId:$id, body:$body}){
      pullRequestReviewComment{ url }
    }
  }' --jq '.data.updatePullRequestReviewComment.pullRequestReviewComment.url'
