#!/usr/bin/env bash
# Post one reply to a comment, appending the idempotency marker (carries the id).
# Prints the created reply's URL (and state, for pending).
#
#   post-comment.sh review  OWNER REPO NUM COMMENT_ID BODY   # published inline thread
#   post-comment.sh issue   OWNER REPO NUM COMMENT_ID BODY   # published conversation
#   post-comment.sh pending THREAD_ID REVIEW_ID COMMENT_ID BODY  # pending reply, stays pending
#
# COMMENT_ID is the numeric databaseId (fetch-*.sh field `id`), never the base64 `node_id`:
# the marker is matched back by `capture("id=[0-9]+")`, so a node_id silently never matches
# and the auto-watcher loops on an already-answered comment.
set -euo pipefail
KIND=$1
mark() {
  case $2 in
    ''|*[!0-9]*) echo "post-comment: comment id '$2' is not numeric (pass the row's databaseId 'id', not 'node_id')" >&2; exit 1 ;;
  esac
  printf '%s\n\n<!-- claude:reply id=%s -->' "$1" "$2"
}

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
