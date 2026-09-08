#!/usr/bin/env bash
# Reviewer inline comments on my PR (Own-PR flow), one row per unresolved
# thread's top-level comment authored by someone else, with my directive comment
# (if any) attached. My directive comment is what Claude edits into the final
# reply to the reviewer.
# Usage: fetch-reviewer-comments.sh OWNER REPO NUM ME
# Prints JSON array of:
#   {id, node_id, path, line, body, diff_hunk, url, thread_id, author,
#    directive, directive_body, directive_id, directive_node_id}
#   directive: "implement" | "reply" | "infer" | null, from my latest comment.
#     "infer" = an untagged follow-up I added to a thread I already tagged;
#     Claude infers intent (clarification -> reply, change -> implement).
#     null = I never tagged this thread, or Claude already handled my latest
#     comment (it carries the claude:reply marker).
#   directive_*: my latest comment (the one to rewrite), null when nothing to do.
set -euo pipefail
O=$1 R=$2 N=$3 ME=$4

threads=$(gh api graphql -F owner="$O" -F repo="$R" -F num="$N" -f query='
  query($owner:String!,$repo:String!,$num:Int!){
    repository(owner:$owner,name:$repo){ pullRequest(number:$num){
      reviewThreads(first:100){ nodes{ id isResolved comments(first:100){ nodes{
        id databaseId path line originalLine body diffHunk url state
        author{login} replyTo{databaseId}
      }}}}
    }}}' 2>/dev/null || echo '{}')

echo "$threads" | jq --arg me "$ME" '
  def dir:
    (capture("(^|\\n)\\s*/(?<d>ask|implement|reply|a|i|r)\\b").d // null) as $d
    | if $d==null then null else ({a:"ask",i:"implement",r:"reply"}[$d] // $d) end;
  def marked: ((. // "") | contains("claude:reply"));
  [ (.data.repository.pullRequest.reviewThreads.nodes // [])[]
    | select(.isResolved|not)
    | .id as $tid
    | .comments.nodes as $cs
    # top-level comment = first in thread, authored by someone else
    | ($cs[0]) as $top
    | select($top.author.login != $me)
    | ( [ $cs[] | select(.author.login==$me) ] ) as $mine   # my comments, newest last
    | ( $mine | last ) as $latest
    # engaged: I tagged Claude here before (a directive) or Claude answered (marker)
    | ( [ $mine[] | ((.body|dir)!=null) or (.body|marked) ] | any ) as $engaged
    | ( if   $latest==null            then null       # I have not commented
        elif ($latest.body|marked)    then null       # Claude already handled my latest
        elif ($latest.body|dir)!=null then ($latest.body|dir)   # explicit /directive
        elif $engaged                 then "infer"    # untagged follow-up in a tagged thread
        else null end ) as $d                          # untagged, untagged thread: reviewer talk
    | { id:$top.databaseId, node_id:$top.id, path:$top.path,
        line:($top.line // $top.originalLine), body:$top.body,
        diff_hunk:$top.diffHunk, url:$top.url, thread_id:$tid,
        author:$top.author.login,
        directive:$d,
        directive_body:(if $d==null then null else $latest.body end),
        directive_id:(if $d==null then null else $latest.databaseId end),
        directive_node_id:(if $d==null then null else $latest.id end) } ]'
