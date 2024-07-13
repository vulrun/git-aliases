#!/usr/bin/env bash
# Git Aliases

{ # this ensures the entire script is downloaded #

  # helpers
  # ----------------------------------------------------------------------------------
  git_echo() {
    command printf %s\\n "$*" 2>/dev/null
  }

  git_exit() {
    # catch errors, if any
    if [ $? -ne 0 ]; then
      echo
      echo "==> Exiting to another space, there seems to be an error."
    fi
  }

  git_detect_remote() {
    if [[ -z "$1" ]]; then
      _ORIGIN="$(git remote)"
      _LENGTH="$(git remote | wc -l)"
      if [[ _LENGTH -eq 1 ]]; then
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
      echo ">> your commit message adheres to the commit rules"
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
  # git aliases decription
  git-aliases() { (
    set -e #fail early

    git_echo "git-aliases is at $(git-ver)"
  ) || git_exit; }

  # gives current git version
  git-ver() { (
    set -e #fail early

    git_echo "v1.1-beta"
  ) || git_exit; }

  # long list of commit history
  git-ll() { (
    set -e #fail early

    git log --abbrev-commit --decorate --pretty=format:"%C(yellow)%h %C(reset)-%C(red)%d %C(reset)%s %C(green)(%ar) %C(blue)[%an]" "$@"
  ) || git_exit; }

  # stage changes & commit
  git-it() { (
    set -e #fail early

    git add --all

    git_commit_lint "$1"
    git commit -m "$1"
  ) || git_exit; }

  # commit changes & push
  git-up() { (
    set -e #fail early

    git-it "$1"
    git-push "${@:2}"
  ) || git_exit; }

  # modify last commit
  git-amend() { (
    set -e #fail early

    git add --all

    if [[ -n "$1" ]]; then
      git_commit_lint "$1"
      git commit --amend --reset-author --message="$1"
    else
      git commit --amend --reset-author --no-edit
    fi
    # in case to modify date: git commit --amend --date="$(date -R)"
  ) || git_exit; }

  # push changes to remote
  git-push() { (
    set -e #fail early

    if [[ -z "$1" ]]; then local _ORIGIN; fi
    if [[ -z "$2" ]]; then local _BRANCH; fi
    git_detect_remote "${@:1:2}"

    git push "${_ORIGIN}" "${_BRANCH}" "${@:3}"
  ) || git_exit; }

  # push changes forcefully to remote
  git-pushf() { (
    set -e #fail early

    if [[ -z "$1" ]]; then local _ORIGIN; fi
    if [[ -z "$2" ]]; then local _BRANCH; fi
    git_detect_remote "${@:1:2}"

    git push --force "${_ORIGIN}" "${_BRANCH}" "${@:3}"
  ) || git_exit; }

  # pull changes from remote
  git-pull() { (
    set -e #fail early

    if [[ -z "$1" ]]; then local _ORIGIN; fi
    if [[ -z "$2" ]]; then local _BRANCH; fi
    git_detect_remote "${@:1:2}"

    git pull "${_ORIGIN}" "${_BRANCH}" "${@:3}"
  ) || git_exit; }

  # update local code as per remote
  git-pullf() { (
    set -e #fail early

    if [[ -z "$1" ]]; then local _ORIGIN; fi
    if [[ -z "$2" ]]; then local _BRANCH; fi
    git_detect_remote "${@:1:2}"

    git fetch --all
    git reset --hard "$_ORIGIN/$_BRANCH"
  ) || git_exit; }

  # remove unwanted reflogs
  git-clean() { (
    set -e #fail early

    if [[ -n "$1" ]]; then
      git reflog expire --expire-unreachable=now --all
    else
      git gc --prune=now --aggressive
    fi

    git_echo
    git_echo "==> Git Repository Cleaned"
    git_echo
  ) || git_exit; }

  # clear the workspace
  git-clear() { (
    set -e #fail early

    git reset --hard
    git clean -df

    git_echo
    git_echo "==> Git Repository Cleared"
    git_echo
  ) || git_exit; }

  # sync everything
  git-sync() { (
    set -e #fail early

    if [[ -z "$1" ]]; then local _ORIGIN; fi
    if [[ -z "$2" ]]; then local _BRANCH; fi
    git_detect_remote "${@:1:2}"

    git stash
    git fetch --all
    git checkout "$_BRANCH"
    git reset --hard "$_ORIGIN/$_BRANCH"
    git remote prune "$_ORIGIN"
    git stash pop

    git_echo
    git_echo "==> Synced with '$_ORIGIN/$_BRANCH'"
    git_echo
  ) || git_exit; }

  # fix for previous commit
  git-fixit() { (
    set -e #fail early

    local _HASH="${1:-HEAD}"

    # Get a commit ref (long-hash-id)
    _HASH="$(git rev-parse "$_HASH")"

    git add --all
    git commit --no-verify --fixup "$_HASH"
  ) || git_exit; }

  # fix commit & push changes
  git-fixup() { (
    set -e #fail early

    git-fixit "$1"
    git-push "${@:2}"
  ) || git_exit; }

  # rebase all commit automatically
  git-rebase() { (
    set -e #fail early

    EDITOR=true git rebase --interactive --autosquash --autostash --rebase-merges --no-fork-point "$@"
  ) || git_exit; }

  # add merge
  git-merge() { (
    set -e #fail early

    if [[ -z "$1" ]]; then exit 1; fi

    if [[ -n "$2" ]]; then
      EDITOR=true git merge "$1" --no-ff -m "$2"
    else
      EDITOR=true git merge "$1" --no-ff --log
    fi
  ) || git_exit; }

  # reset commit
  git-reset() { (
    set -e #fail early

    if [[ -n "$1" ]]; then
      git reset --soft "$1"
    else
      git reset --soft HEAD^
    fi
  ) || git_exit; }

  # reset commit forcefully
  git-resetf() { (
    set -e #fail early

    if [[ -n "$1" ]]; then
      git reset --hard "$1"
    else
      git reset --hard HEAD^
    fi
  ) || git_exit; }

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
    complete -W "$(__git_branches)" git-reset
    complete -W "$(__git_branches)" git-resetf
  fi

} # this ensures the entire script is downloaded #
