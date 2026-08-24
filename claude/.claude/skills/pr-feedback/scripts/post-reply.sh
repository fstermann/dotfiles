#!/usr/bin/env bash
# Post one reply to a comment, appending the idempotency marker (carries the id).
# Prints the created reply's URL (and state, for pending).
#
#   post-reply.sh review  OWNER REPO NUM COMMENT_ID BODY   # published inline thread
#   post-reply.sh issue   OWNER REPO NUM COMMENT_ID BODY   # published conversation
#   post-reply.sh pending THREAD_ID REVIEW_ID COMMENT_ID BODY  # draft reply, stays pending
set -euo pipefail
KIND=$1
mark() { printf '%s\n\n<!-- claude-pr-feedback id=%s -->' "$1" "$2"; }

case "$KIND" in
  review)
    O=$2 R=$3 N=$4 ID=$5 BODY=$6
    gh api "repos/$O/$R/pulls/$N/comments/$ID/replies" \
      -f body="$(mark "$BODY" "$ID")" --jq '.html_url' ;;
  issue)
    O=$2 R=$3 N=$4 ID=$5 BODY=$6
    gh api "repos/$O/$R/issues/$N/comments" \
      -f body="$(mark "$BODY" "$ID")" --jq '.html_url' ;;
  pending)
    TID=$2 RID=$3 ID=$4 BODY=$5
    gh api graphql -f threadId="$TID" -f reviewId="$RID" -f body="$(mark "$BODY" "$ID")" -f query='
      mutation($threadId:ID!,$reviewId:ID!,$body:String!){
        addPullRequestReviewThreadReply(input:{
          pullRequestReviewThreadId:$threadId, pullRequestReviewId:$reviewId, body:$body
        }){ comment{ url state } }
      }' --jq '.data.addPullRequestReviewThreadReply.comment | "\(.url) (\(.state))"' ;;
  *) echo "unknown kind: $KIND (want review|issue|pending)" >&2; exit 1 ;;
esac
