#!/usr/bin/env bash
# Git Aliases

{ # this ensures the entire script is downloaded #

  # helpers
  # ----------------------------------------------------------------------------------
  git_echo() {
    command printf %s\\n "$*" 2>/dev/null
  }

  git_exit() {
    # Catch errors, if any
    if [ $? -ne 0 ]; then
      echo
      echo "==> ${1:-"Exiting, some unknown error occurred"}"
      echo
    fi
  }

  git_detect_remote() {
    if [[ -z "$1" ]]; then
      _ORIGIN="$(git remote)"
      _LENGTH="$(git remote | wc -l)"
      if [[ $_LENGTH -eq 1 ]]; then
        git_echo "==> Detected Remote: $_ORIGIN"
      else
        git_echo "==> Multiple Remotes Detected:"
        git_echo "$_ORIGIN"
        exit 1
      fi
    else
      _ORIGIN="$1"
      git_echo "==> Requested Remote: $_ORIGIN"
    fi

    if [[ -z "$2" ]]; then
      _BRANCH="$(git rev-parse --abbrev-ref HEAD)"
      git_echo "==> Detected Branch: $_BRANCH"
    else
      _BRANCH="$2"
      git_echo "==> Requested Branch: $_BRANCH"
    fi
  }

  git_commit_lint() {
    local message_string="$1"
    # Regular expression pattern
    regex="^(build|chore|ci|docs|feat|fix|perf|refactor|revert|style)(\([a-zA-Z0-9]+\))?: .*$"

    if [[ $message_string =~ $regex ]]; then
      echo ">> Your commit message adheres to the commit rules"
      echo
    else
      echo
      echo "Oops! Your commit message does not conform to the commit rules."
      echo "Please ensure your commit message follows the conventional commits format:"
      echo "  type(scope): description"
      echo "Where:"
      echo "  - 'type' could be one of: build, chore, ci, docs, feat, fix, perf, refactor, revert, style"
      echo "  - 'scope' is optional and can be anything specifying the place of the commit change"
      echo "  - 'description' is a short description of the change"
      exit 1
    fi
  }

  # aliases
  # ----------------------------------------------------------------------------------
  # git aliases description
  git-aliases() { (
    set -e #fail early

    git_echo "git-aliases is at $(git-ver)"
  ) || git_exit "Failed to display git aliases version"; }

  # gives current git version
  git-ver() { (
    set -e #fail early

    git_echo "v1.2-beta"
  ) || git_exit "Failed to retrieve git version"; }

  # long list of commit history
  git-ll() { (
    set -e #fail early

    git log --abbrev-commit --decorate --pretty=format:"%C(yellow)%h %C(reset)-%C(red)%d %C(reset)%s %C(green)(%ar) %C(blue)[%an]" "$@"
  ) || git_exit "Failed to display commit history"; }

  # stage changes & commit
  git-it() { (
    set -e #fail early

    git add --all

    git_commit_lint "$1"
    git commit -m "$1"
  ) || git_exit "Failed to stage and commit changes"; }

  # commit changes & push
  git-up() { (
    set -e #fail early

    git-it "$1"
    git-push "${@:2}"
  ) || git_exit "Failed to commit and push changes"; }

  # modify last commit
  git-amend() { (
    set -e #fail early

    git add --all

    if [[ -n "$1" ]]; then
      git_commit_lint "$1"
      git commit --amend --message="$1"
    else
      git commit --amend --no-edit
    fi
  ) || git_exit "Failed to amend the last commit"; }

  # modify last commit with current time
  git-amend-now() { (
    set -e #fail early

    git add --all

    if [[ -n "$1" ]]; then
      git_commit_lint "$1"
      git commit --amend --reset-author --message="$1"
    else
      git commit --amend --reset-author --no-edit
    fi
  ) || git_exit "Failed to amend the last commit with the current time"; }

  # push changes to remote
  git-push() { (
    set -e #fail early

    if [[ -z "$1" ]]; then local _ORIGIN; fi
    if [[ -z "$2" ]]; then local _BRANCH; fi
    git_detect_remote "${@:1:2}"

    git push "${_ORIGIN}" "${_BRANCH}" "${@:3}"
  ) || git_exit "Failed to push changes"; }

  # push changes forcefully to remote
  git-pushf() { (
    set -e #fail early

    if [[ -z "$1" ]]; then local _ORIGIN; fi
    if [[ -z "$2" ]]; then local _BRANCH; fi
    git_detect_remote "${@:1:2}"

    git push --force "${_ORIGIN}" "${_BRANCH}" "${@:3}"
  ) || git_exit "Failed to force push changes"; }

  # pull changes from remote
  git-pull() { (
    set -e #fail early

    if [[ -z "$1" ]]; then local _ORIGIN; fi
    if [[ -z "$2" ]]; then local _BRANCH; fi
    git_detect_remote "${@:1:2}"

    git pull "${_ORIGIN}" "${_BRANCH}" "${@:3}"
  ) || git_exit "Failed to pull changes"; }

  # update local code as per remote
  git-pullf() { (
    set -e #fail early

    if [[ -z "$1" ]]; then local _ORIGIN; fi
    if [[ -z "$2" ]]; then local _BRANCH; fi
    git_detect_remote "${@:1:2}"

    git fetch --all
    git reset --hard "$_ORIGIN/$_BRANCH"
  ) || git_exit "Failed to forcibly update local code"; }

  # remove unwanted reflogs
  git-clean() { (
    set -e #fail early

    git gc --prune=now --aggressive

    git_echo
    git_echo "==> Git Repository Cleaned"
    git_echo
  ) || git_exit "Failed to clean the git repository"; }

  # clear the workspace
  git-clear() { (
    set -e #fail early

    git reset --hard
    git clean -df

    git_echo
    git_echo "==> Git Repository Cleared"
    git_echo
  ) || git_exit "Failed to clear the git repository"; }

  # sync everything
  git-sync() { (
    set -e #fail early

    if [[ -z "$1" ]]; then local _ORIGIN; fi
    if [[ -z "$2" ]]; then local _BRANCH; fi
    git_detect_remote "${@:1:2}"

    git add --all
    git stash
    git fetch --all
    git checkout "$_BRANCH"
    git reset --hard "$_ORIGIN/$_BRANCH"
    git remote prune "$_ORIGIN"
    git stash pop

    git_echo
    git_echo "==> Synced with '$_ORIGIN/$_BRANCH'"
    git_echo
  ) || git_exit "Failed to sync with remote"; }

  # fix for previous commit
  git-fixit() { (
    set -e #fail early

    local _HASH="${1:-HEAD}"

    _HASH="$(git rev-parse "$_HASH")"

    git add --all
    git commit --no-verify --fixup "$_HASH"
  ) || git_exit "Failed to create a fixup commit"; }

  # fix commit & push changes
  git-fixup() { (
    set -e #fail early

    git-fixit "$1"
    git-push "${@:2}"
  ) || git_exit "Failed to fixup and push changes"; }

  # rebase all commit automatically
  git-rebase() { (
    set -e #fail early

    EDITOR=true git rebase --interactive --autosquash --autostash --rebase-merges --no-fork-point "$@"
  ) || git_exit "Failed to rebase commits"; }

  # add merge
  git-merge() { (
    set -e #fail early

    if [[ -z "$1" ]]; then
      echo "Error: No branch specified."
      exit 1
    fi

    current_branch=$(git rev-parse --abbrev-ref HEAD)

    if [[ "$current_branch" == "$1" ]]; then
      echo "Error: You cannot merge into the same branch you are currently on."
      exit 1
    fi

    if [[ -n "$2" ]]; then
      EDITOR=true git merge "$1" --no-ff -m "$2"
    else
      EDITOR=true git merge "$1" --no-ff --log
    fi
  ) || git_exit "Failed to merge branch"; }

  git-merge-to() { (
    set -e # fail early

    if [[ -z "$1" ]]; then
      echo "Error: No branch specified."
      exit 1
    fi

    current_branch=$(git rev-parse --abbrev-ref HEAD)

    if [[ "$current_branch" == "$1" ]]; then
      echo "Error: You cannot merge into the same branch you are currently on."
      exit 1
    fi

    if [[ -n "$2" ]]; then
      git checkout "$1"
      EDITOR=true git merge "$current_branch" --no-ff -m "$2"
    else
      git checkout "$1"
      EDITOR=true git merge "$current_branch" --no-ff --log
    fi
    # Checkout back to the original branch
    git checkout "$current_branch"
  ) || git_exit "Failed to merge into target branch"; }

  # reset commit
  git-reset() { (
    set -e #fail early

    if [[ -n "$1" ]]; then
      git reset --soft "$1"
    else
      git reset --soft HEAD^
    fi
  ) || git_exit "Failed to reset commit"; }

  # reset commit forcefully
  git-resetf() { (
    set -e #fail early

    if [[ -n "$1" ]]; then
      git reset --hard "$1"
    else
      git reset --hard HEAD^
    fi
  ) || git_exit "Failed to force reset commit"; }

  # miscellaneous
  # ----------------------------------------------------------------------------------

  __git_branches() {
    if [ -d .git ]; then
      echo "$(git branch -a | sed 's/^[* ]*//; s/remotes\///' | tr '\n' ' ' | xargs)"
    else
      echo ""
    fi
  }

  if command -v git-ver &>/dev/null; then
    complete -W "$(__git_branches)" git-merge
    complete -W "$(__git_branches)" git-merge-to
    complete -W "$(__git_branches)" git-reset
    complete -W "$(__git_branches)" git-resetf
  fi

} # this ensures the entire script is downloaded #
