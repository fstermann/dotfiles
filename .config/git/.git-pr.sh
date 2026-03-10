#!/bin/bash
# git config --global alias.pr '!sh ~/dotfiles/git/.git-pr.sh'
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

read -p "Are you sure you want to create a new PR with title '$title'?"$'\n'"$add_info $current_added_info"$'\n'"Create the PR? [y/N] " -n 1 -r
echo # move to a new line

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "\nPR creation aborted."
  exit 1
fi

# Ask user for issue number
read -p "Closes issue (if any): " issue_number

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

if [ -z "$issue_number" ]; then
    description=""
else
    description='-o merge_request.description="Closes #$issue_number"'
fi

if [ "$only_added" = false ]; then
    git add .
fi

git diff-index --quiet HEAD || git commit -m "$title"
git push $push_option -o merge_request.create -o merge_request.title="$title" $description -o merge_request.label="$prefix"

echo "Branch '$branch' created and pushed to origin."
