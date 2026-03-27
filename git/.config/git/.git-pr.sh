#!/bin/bash
# git config --global alias.pr '!sh ~/.config/git/.git-pr.sh'
set -e


show_help() {
    cat <<EOF
Usage: git pr [COMMIT MESSAGE]

Create a new Git branch and push changes for a pull request.

Options:
  -h, --help      Show this help message and exit.
  --only-added    Only commit files that have been added to the staging area.
  --no-verify     Skip commit message validation.

Requirements:
  A valid commit message must be provided. The format should follow conventional commits:
    (feat|fix|refactor|build|chore|docs|style|test|ci|perf)([scope]): [title]

  Requires 'gh' (GitHub CLI) for GitHub remotes or 'glab' (GitLab CLI) for GitLab remotes.
  Requires 'jq' for JSON parsing.

Examples:
  git pr "feat(scope): add new feature"
  git pr fix: correct typo in documentation
EOF
}

# Check for help option
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_help
    exit 0
fi


if [ $# -eq 0 ]; then
    echo "Error: Commit message required."
    exit 1
fi



title="$@"
# check if contains --only-added option
if [[ "$title" == *"--only-added"* ]]; then
    only_added=true
    title="${title//--only-added/}"  # Remove the option from the title
    changed_files=$(git diff --cached --name-only | sed 's/^/\t/')
    current_added_info="This will only add the following files:"$'\n'"$changed_files"
else
    only_added=false
    changed_files=$(git status --porcelain | awk '{print $2}' | sed 's/^/\t/')
    current_added_info="This will add all changes in the working directory:"$'\n'"$changed_files"
fi

# check if contains --no-verify option
if [[ "$title" == *"--no-verify"* ]]; then
    no_verify=true
    title="${title//--no-verify/}"  # Remove the option from the title
else
    no_verify=false
fi

# Clean up any extra spaces in title
title=$(echo "$title" | sed 's/  */ /g' | sed 's/^ *//;s/ *$//')

if [[ "$no_verify" != true ]] && [[ ! "$title" =~ ^(Draft:\ )?(feat|fix|refactor|build|chore|docs|style|test|ci|perf)(\([^\)]+\))?:\ .+$ ]]; then
    echo "Commit message is invalid: $title"
    exit 1
fi

full_prefix=$(echo "$title" | cut -d: -f1)
prefix=$(echo "$full_prefix" | cut -d\( -f1)
scope=$(echo "$full_prefix" | sed -n 's/.*(\(.*\)).*/\1/p')

current_branch=$(git rev-parse --abbrev-ref HEAD)
branch_suffix=$(echo "$title" | cut -d: -f2- | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//;s/-$//')
if [ -n "$scope" ]; then
    branch="$prefix/$scope/$branch_suffix"
else
    branch="$prefix/$branch_suffix"
fi

if [ "$current_branch" = "$branch" ]; then
    add_info="This will reuse the current branch '$branch'."
else
    add_info="This will create a new branch '$branch'."
fi

# Detect remote type (GitHub vs GitLab)
remote_url=$(git remote get-url origin 2>/dev/null || echo "")
if [[ "$remote_url" == *"github.com"* ]]; then
    remote_type="github"
else
    remote_type="gitlab"
fi

# Derive issue title from commit message: "feat(scope): add config files" -> "Feat: Add config files"
prefix_cap="$(echo "${prefix:0:1}" | tr '[:lower:]' '[:upper:]')${prefix:1}"
issue_subject=$(echo "$title" | sed 's/^[^:]*:[[:space:]]*//')
issue_subject_cap="$(echo "${issue_subject:0:1}" | tr '[:lower:]' '[:upper:]')${issue_subject:1}"
issue_title="$prefix_cap: $issue_subject_cap"

read -p "Are you sure you want to create a new PR with title '$title'?"$'\n'"$add_info $current_added_info"$'\n'"An issue '$issue_title' will be found or created."$'\n'"Create the PR? [y/N] " -n 1 -r
echo # move to a new line

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "\nPR creation aborted."
  exit 1
fi

# Find or create the issue
if [ "$remote_type" = "github" ]; then
    # Ensure the label exists (--force creates it if missing, updates if present)
    gh label create "$prefix" --color "#0075ca" --force 2>/dev/null || true

    existing_issue=$(gh issue list --search "$issue_title in:title" --state open --json number,title --limit 20 \
        | jq -r --arg t "$issue_title" '.[] | select(.title == $t) | .number' | head -1)
    if [ -n "$existing_issue" ]; then
        issue_number="$existing_issue"
        echo "Using existing issue #$issue_number: $issue_title"
    else
        echo "Creating issue: $issue_title"
        issue_url=$(gh issue create --title "$issue_title" --body "" --label "$prefix")
        issue_number=$(echo "$issue_url" | grep -o '[0-9]*$')
        echo "Created issue #$issue_number"
    fi
else
    # Ensure the label exists
    glab label create --name "$prefix" --color "#0075ca" 2>/dev/null || true

    existing_issue=$(glab issue list --search "$issue_title" -F json 2>/dev/null \
        | jq -r --arg t "$issue_title" '.[] | select(.title == $t) | .iid' | head -1)
    if [ -n "$existing_issue" ]; then
        issue_number="$existing_issue"
        echo "Using existing issue #$issue_number: $issue_title"
    else
        echo "Creating issue: $issue_title"
        issue_url=$(glab issue create --title "$issue_title" --description "" --label "$prefix" 2>&1 | grep "https://")
        issue_number=$(echo "$issue_url" | grep -o '/issues/[0-9]*' | grep -o '[0-9]*')
        echo "Created issue #$issue_number"
    fi
fi

if [ "$current_branch" != "$branch" ]; then
    git checkout -b "$branch"
fi

if git rev-parse --abbrev-ref --symbolic-full-name @{u} >/dev/null 2>&1; then
    # Local branch has an upstream.
    push_option=""
else
    # Local branch does not have an upstream.
    push_option="-u origin $branch"
fi

if [ "$only_added" = false ]; then
    git add .
fi

git diff-index --quiet HEAD || git commit -m "$title"

if [ "$remote_type" = "github" ]; then
    git push $push_option
    gh pr create --title "$title" --body "Closes #$issue_number" --label "$prefix"
else
    git push $push_option -o merge_request.create -o merge_request.title="$title" -o merge_request.description="Closes #$issue_number" -o merge_request.label="$prefix"
fi

echo "Branch '$branch' created and pushed to origin."
