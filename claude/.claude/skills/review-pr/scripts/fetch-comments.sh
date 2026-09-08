#!/usr/bin/env bash
# Fetch my unanswered comments on a PR from all sources, normalized.
# Pending comments come via GraphQL, carrying real line + thread/review ids so
# they can receive a pending reply. Already-answered comments (a reply whose
# marker cites their id) are dropped.
# Usage: fetch-comments.sh OWNER REPO NUM ME
# My comments (Own-PR flow uses all; Reviewing flow uses source:pending). For
# reviewers' comments on my PR, use fetch-reviewer-comments.sh instead.
# Prints JSON array of:
#   {id, node_id, source:review|pending|issue, path, line, body, diff_hunk, url,
#    thread_id, review_id, has_fence, directive}
#   node_id: GraphQL id for edit-comment.sh / delete-comment.sh.
#   has_fence: body already carries a <!-- claude:start --> block.
#   directive: /ask, /implement, or /reply parsed from the body, else null.
set -euo pipefail
O=$1 R=$2 N=$3 ME=$4
MARKER='claude:reply'

pub=$(gh api "repos/$O/$R/pulls/$N/comments" --paginate)
iss=$(gh api "repos/$O/$R/issues/$N/comments" --paginate)

# Pending comments: reviewThreads gives real line numbers + the thread/review ids
# needed to reply into my existing pending review.
threads=$(gh api graphql -F owner="$O" -F repo="$R" -F num="$N" -f query='
  query($owner:String!,$repo:String!,$num:Int!){
    repository(owner:$owner,name:$repo){ pullRequest(number:$num){
      reviewThreads(first:100){ nodes{ id comments(first:100){ nodes{
        id databaseId path line originalLine body diffHunk url state
        author{login} replyTo{databaseId} pullRequestReview{id}
      }}}}
    }}}' 2>/dev/null || echo '{}')

pend=$(echo "$threads" | jq --arg me "$ME" '
  [ (.data.repository.pullRequest.reviewThreads.nodes // [])[]
    | .id as $tid
    | .comments.nodes[]
    | select(.state=="PENDING" and .author.login==$me)
    | { id:.databaseId, node_id:.id, path, line:(.line // .originalLine), body,
        diff_hunk:.diffHunk, url, thread_id:$tid,
        review_id:.pullRequestReview.id, reply_to:(.replyTo.databaseId // null) } ]')

# Payloads go in via --slurpfile (process substitution), not --argjson: a large PR's comment
# blob would blow past ARG_MAX on the argv and fail with "Argument list too long". slurpfile
# wraps each file's single JSON value in an array, so unwrap with [0].
jq -n --arg me "$ME" --arg marker "$MARKER" \
      --slurpfile pub <(printf '%s' "$pub") \
      --slurpfile iss <(printf '%s' "$iss") \
      --slurpfile pend <(printf '%s' "$pend") '
  def dir:
    (capture("(^|\\n)\\s*/(?<d>ask|implement|reply|a|i|r)\\b").d // null) as $d
    | if $d==null then null else ({a:"ask",i:"implement",r:"reply"}[$d] // $d) end;
  def fence: (contains("claude:start"));
  ($pub[0]) as $pub | ($iss[0]) as $iss | ($pend[0]) as $pend
  | ($pub + $iss + $pend) as $all
  | ([ $all[] | select(.body|contains($marker)) | (.body|capture("id=(?<n>[0-9]+)")|.n|tonumber)? ]) as $answered
  # Replies are kept, not just top-level comments: a follow-up I post inside a thread I already
  # answered reopens it, and would otherwise be invisible. My own marker-replies carry the marker
  # (dropped below) and every already-answered id is in $answered, so neither is re-surfaced.
  | ( $pub
      | map(select(.user.login==$me
                   and (.body|contains($marker)|not) and (.id | IN($answered[]) | not)))
      | map({id, node_id:.node_id, source:"review", path, line:(.line // .original_line), body,
             diff_hunk, url:.html_url, thread_id:null, review_id:null,
             has_fence:(.body|fence), directive:(.body|dir)}) )
  + ( $pend
      | map(select((.body|contains($marker)|not) and (.id | IN($answered[]) | not)))
      | map({id, node_id, source:"pending", path, line, body, diff_hunk, url, thread_id, review_id,
             has_fence:(.body|fence), directive:(.body|dir)}) )
  + ( $iss
      | map(select(.user.login==$me and (.body|contains($marker)|not) and (.id | IN($answered[]) | not)))
      | map({id, node_id:.node_id, source:"issue", path:null, line:null, body, diff_hunk:"",
             url:.html_url, thread_id:null, review_id:null,
             has_fence:(.body|fence), directive:(.body|dir)}) )
'
