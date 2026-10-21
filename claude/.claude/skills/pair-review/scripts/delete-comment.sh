#!/usr/bin/env bash
# Delete a review comment via GraphQL. Used to auto-fold my replies into the
# one thread comment (Reviewing flow). Destructive: only call on my own comments.
# Usage: delete-comment.sh NODE_ID
#   NODE_ID: the comment's GraphQL node id (fetch-comments.sh field `node_id`).
set -euo pipefail
ID=$1
gh api graphql -f id="$ID" -f query='
  mutation($id:ID!){
    deletePullRequestReviewComment(input:{id:$id}){
      pullRequestReviewComment{ databaseId }
    }
  }' --jq '.data.deletePullRequestReviewComment.pullRequestReviewComment.databaseId'
