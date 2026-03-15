#!/bin/bash
# git config --global alias.remerge '!sh ~/.config/git/.git-remerge.sh'
set -e

# Function to display help message
show_help() {
  cat << EOF
Usage: git remerge [TARGET_BRANCH] [SOURCE_BRANCH]

Remerges the SOURCE_BRANCH onto the TARGET_BRANCH.

Options:
  TARGET_BRANCH    The branch to remerge onto (default: current branch).
  SOURCE_BRANCH    The branch to remerge from (default: 'main').

If TARGET_BRANCH and SOURCE_BRANCH are not provided, the script will use the 
current branch as the target and 'main' as the source branch.

Example:
  git remerge feature-branch develop

This will remerge 'develop' onto 'feature-branch'.

EOF
}

# Check if help is requested
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
  show_help
  exit 0
fi

target_branch="${1:-$(git rev-parse --abbrev-ref HEAD)}"
source_branch="${2:-main}"

read -p "Are you sure you want to remerge '$source_branch' onto '$target_branch'? [y/N] " -n 1 -r
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "\nRemerge aborted."
  exit 1
fi

git fetch
git checkout "$source_branch"
git pull
git checkout "$target_branch"
git pull
git merge "$source_branch" --no-edit
git push --force-with-lease

# To enable autocompletion for `git remerge`, add the following to your `.zshrc/.bashrc`:
# _git_remerge ()
# {
# 	__git_complete_strategy && return
# 	case "$cur" in
# 	--*)
# 		__gitcomp_builtin merge
# 		return
# 	esac
# 	__git_complete_refs
# }