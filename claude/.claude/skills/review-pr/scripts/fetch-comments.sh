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
#    thread_id, review_id, has_fence, directive, reply_to, thread_engaged}
#   node_id: GraphQL id for edit-comment.sh / delete-comment.sh.
#   has_fence: body already carries a <!-- claude:start --> block.
#   directive: /ask, /implement, or /reply parsed from the body, else null.
#   reply_to: parent comment id this pending row folds into (thread order, see below),
#     else null. Only meaningful for source:pending.
#   thread_engaged: some comment in this thread carries a directive, so an untagged
#     follow-up here still counts as work. Only meaningful for source:pending.
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

# reply_to links a follow-up to the comment it folds into. GitHub only sets its own
# replyTo when I use the Reply button; a fresh comment typed on the same line joins the
# thread with replyTo null. So fall back to thread order: the first of my pending comments
# in a thread is the parent, every later one folds into it.
pend=$(echo "$threads" | jq --arg me "$ME" '
  [ (.data.repository.pullRequest.reviewThreads.nodes // [])[]
    | .id as $tid
    | ( [ .comments.nodes[] | select(.state=="PENDING" and .author.login==$me) ] ) as $mine
    | ($mine[0].databaseId) as $parent
    # Engaged = any of my comments here carries a directive; lets an untagged follow-up count.
    | ( [ $mine[].body ] | any(test("(^|\\n)\\s*/(ask|implement|reply|a|i|r)\\b")) ) as $engaged
    | ($mine | to_entries[])
    | { id:.value.databaseId, node_id:.value.id, path:.value.path,
        line:(.value.line // .value.originalLine), body:.value.body,
        diff_hunk:.value.diffHunk, url:.value.url, thread_id:$tid,
        review_id:.value.pullRequestReview.id, thread_engaged:$engaged,
        reply_to:(.value.replyTo.databaseId // (if .key==0 then null else $parent end)) } ]')

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
             has_fence:(.body|fence), directive:(.body|dir), reply_to, thread_engaged}) )
  + ( $iss
      | map(select(.user.login==$me and (.body|contains($marker)|not) and (.id | IN($answered[]) | not)))
      | map({id, node_id:.node_id, source:"issue", path:null, line:null, body, diff_hunk:"",
             url:.html_url, thread_id:null, review_id:null,
             has_fence:(.body|fence), directive:(.body|dir)}) )
'
