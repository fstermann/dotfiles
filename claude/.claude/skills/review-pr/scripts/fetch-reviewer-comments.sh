#!/usr/bin/env bash
# Reviewer inline comments on my PR (Own-PR flow), one row per unresolved
# thread's top-level comment authored by someone else, with my directive comment
# (if any) attached. My directive comment is what Claude edits into the final
# reply to the reviewer.
# Usage: fetch-reviewer-comments.sh OWNER REPO NUM ME
# Prints JSON array of:
#   {id, node_id, path, line, body, diff_hunk, url, thread_id, author,
#    directive, directive_body, directive_id, directive_node_id}
#   directive: "implement" | "reply" | null (parsed from my latest comment).
#   directive_*: my comment carrying the directive (null when I left none).
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
  [ (.data.repository.pullRequest.reviewThreads.nodes // [])[]
    | select(.isResolved|not)
    | .id as $tid
    | .comments.nodes as $cs
    # my latest comment that carries a directive
    | ( [ $cs[] | select(.author.login==$me and (.body|dir)!=null) ] | last ) as $d
    # top-level comment = first in thread, authored by someone else
    | ($cs[0]) as $top
    | select($top.author.login != $me)
    | { id:$top.databaseId, node_id:$top.id, path:$top.path,
        line:($top.line // $top.originalLine), body:$top.body,
        diff_hunk:$top.diffHunk, url:$top.url, thread_id:$tid,
        author:$top.author.login,
        directive:($d.body|dir),
        directive_body:$d.body,
        directive_id:$d.databaseId,
        directive_node_id:$d.id } ]'
