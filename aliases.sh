#!/usr/bin/env bash
# Git Aliases

{ # this ensures the entire script is downloaded #

  # helpers
  # ----------------------------------------------------------------------------------
  git_echo() {
    command printf %s\\n "$*" 2> /dev/null
  }

  git_exit() {
    # Report the failure of the previous command, if any, and pass its status on
    local rc=$?
    if [ $rc -ne 0 ]; then
      echo >&2
      echo "==> ${1:-"Exiting, some unknown error occurred"}" >&2
      echo >&2
    fi
    return $rc
  }

  git_detect_remote() {
    if [[ -z $1 ]]; then
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

    if [[ -z $2 ]]; then
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

  alias git-log="git-ll"
  alias git-logs="git-ll"

  # aliases
  # ----------------------------------------------------------------------------------
  # git aliases description
  git-aliases() { (
    git_echo "git-aliases is at $(git-ver)"
  ) || git_exit "Failed to display git aliases version"; }

  # gives current git version
  git-ver() { (
    git_echo "v1.3-beta"
  ) || git_exit "Failed to retrieve git version"; }

  # long list of commit history
  git-ll() { (
    git log --abbrev-commit --decorate --pretty=format:"%C(yellow)%h %C(reset)-%C(red)%d %C(reset)%s %C(green)(%ar) %C(blue)[%an]" "$@"
  ) || git_exit "Failed to display commit history"; }

  # stage changes & commit
  git-it() { (
    git add --all || exit

    git_commit_lint "$1"
    git commit -m "$1"
  ) || git_exit "Failed to stage and commit changes"; }

  # commit changes & push
  git-up() { (
    git-it "$1" || exit
    git-push "${@:2}"
  ) || git_exit "Failed to commit and push changes"; }

  # modify last commit
  git-amend() { (
    git add --all || exit

    if [[ -n $1 ]]; then
      git_commit_lint "$1"
      git commit --amend --message="$1"
    else
      git commit --amend --no-edit
    fi
  ) || git_exit "Failed to amend the last commit"; }

  # modify last commit with current time
  git-amend-now() { (
    git add --all || exit

    if [[ -n $1 ]]; then
      git_commit_lint "$1"
      git commit --amend --reset-author --message="$1"
    else
      git commit --amend --reset-author --no-edit
    fi
  ) || git_exit "Failed to amend the last commit with the current time"; }

  # push changes to remote
  git-push() { (
    if [[ -z $1 ]]; then local _ORIGIN; fi
    if [[ -z $2 ]]; then local _BRANCH; fi
    git_detect_remote "${@:1:2}"

    git push "${_ORIGIN}" "${_BRANCH}" "${@:3}"
  ) || git_exit "Failed to push changes"; }

  # push changes forcefully to remote
  git-pushf() { (
    if [[ -z $1 ]]; then local _ORIGIN; fi
    if [[ -z $2 ]]; then local _BRANCH; fi
    git_detect_remote "${@:1:2}"

    git push --force "${_ORIGIN}" "${_BRANCH}" "${@:3}"
  ) || git_exit "Failed to force push changes"; }

  # pull changes from remote
  git-pull() { (
    if [[ -z $1 ]]; then local _ORIGIN; fi
    if [[ -z $2 ]]; then local _BRANCH; fi
    git_detect_remote "${@:1:2}"

    git pull "${_ORIGIN}" "${_BRANCH}" "${@:3}"
  ) || git_exit "Failed to pull changes"; }

  # update local code as per remote
  git-pullf() { (
    if [[ -z $1 ]]; then local _ORIGIN; fi
    if [[ -z $2 ]]; then local _BRANCH; fi
    git_detect_remote "${@:1:2}"

    git fetch --all || exit
    git reset --hard "$_ORIGIN/$_BRANCH"
  ) || git_exit "Failed to forcibly update local code"; }

  # remove unwanted reflogs
  git-clean() { (
    git gc --prune=now --aggressive || exit

    git_echo
    git_echo "==> Git Repository Cleaned"
    git_echo
  ) || git_exit "Failed to clean the git repository"; }

  # clear the workspace
  git-clear() { (
    git reset --hard || exit
    git clean -df || exit

    git_echo
    git_echo "==> Git Repository Cleared"
    git_echo
  ) || git_exit "Failed to clear the git repository"; }

  # sync everything
  git-sync() { (
    set -e #fail early

    if [[ -z $1 ]]; then local _ORIGIN; fi
    if [[ -z $2 ]]; then local _BRANCH; fi
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
    local _HASH="${1:-HEAD}"

    _HASH="$(git rev-parse "$_HASH")" || exit

    git add --all || exit
    git commit --no-verify --fixup "$_HASH"
  ) || git_exit "Failed to create a fixup commit"; }

  # fix commit & push changes
  git-fixup() { (
    git-fixit "$1" || exit
    git-push "${@:2}"
  ) || git_exit "Failed to fixup and push changes"; }

  # rebase all commit automatically
  git-rebase() { (
    EDITOR=true git rebase --interactive --autosquash --autostash --rebase-merges --no-fork-point "$@"
  ) || git_exit "Failed to rebase commits"; }

  # add merge
  git-merge() { (
    if [[ -z $1 ]]; then
      echo "Error: No branch specified."
      exit 1
    fi

    current_branch=$(git rev-parse --abbrev-ref HEAD) || exit

    if [[ $current_branch == "$1" ]]; then
      echo "Error: You cannot merge into the same branch you are currently on."
      exit 1
    fi

    if [[ -n $2 ]]; then
      EDITOR=true git merge "$1" --no-ff -m "$2"
    else
      EDITOR=true git merge "$1" --no-ff --log
    fi
  ) || git_exit "Failed to merge branch"; }

  git-merge-to() { (
    if [[ -z $1 ]]; then
      echo "Error: No branch specified."
      exit 1
    fi

    current_branch=$(git rev-parse --abbrev-ref HEAD) || exit

    if [[ $current_branch == "$1" ]]; then
      echo "Error: You cannot merge into the same branch you are currently on."
      exit 1
    fi

    git checkout "$1" || exit
    if [[ -n $2 ]]; then
      EDITOR=true git merge "$current_branch" --no-ff -m "$2"
    else
      EDITOR=true git merge "$current_branch" --no-ff --log
    fi || exit
    # Checkout back to the original branch
    git checkout "$current_branch"
  ) || git_exit "Failed to merge into target branch"; }

  # reset commit
  git-reset() { (
    if [[ -n $1 ]]; then
      git reset --soft "$1"
    else
      git reset --soft HEAD^
    fi
  ) || git_exit "Failed to reset commit"; }

  # reset commit forcefully
  git-resetf() { (
    if [[ -n $1 ]]; then
      git reset --hard "$1"
    else
      git reset --hard HEAD^
    fi
  ) || git_exit "Failed to force reset commit"; }

  # stash all changes
  git-stash() { (
    git stash push -u

  ) || git_exit "Failed to stash all changes"; }

  # stash only staged files
  git-sstash() { (
    cd "$(git rev-parse --show-toplevel)" || exit

    if git diff-index --cached --quiet HEAD; then
      git_echo "==> No staged changes to stash"
      exit
    fi

    # refuse before touching anything if unstaged edits overlap the staged ones
    git diff-index --cached --binary HEAD | git apply --reverse --check || exit

    # record the staged state as a regular stash entry
    branch="$(git rev-parse --abbrev-ref HEAD)" || exit
    tree="$(git write-tree)" || exit
    index="$(git commit-tree --no-gpg-sign -p HEAD -m "index on $branch" "$tree")" || exit
    stash="$(git commit-tree --no-gpg-sign -p HEAD -p "$index" -m "On $branch: git-sstash" "$tree")" || exit
    git stash store -m "On $branch: git-sstash" "$stash" || exit

    # take the staged changes out of the working tree and index, leaving the unstaged ones
    git diff-index --cached --binary HEAD | git apply --reverse || exit
    git reset -q
  ) || git_exit "Failed to stash staged changes"; }

  # stash only unstaged and untracked files
  git-nstash() { (
    # nothing staged: a plain stash already holds just the unstaged changes
    if git diff-index --cached --quiet HEAD; then
      git stash push --include-untracked
      exit
    fi

    # park the staged changes in a temporary commit so the stash is taken on top of them
    head="$(git rev-parse HEAD)" || exit
    tmp="$(git commit-tree --no-gpg-sign -p HEAD -m "git-nstash: staged changes" "$(git write-tree)")" || exit
    git reset -q --soft "$tmp" || exit

    git stash push --include-untracked
    rc=$?

    # move HEAD back; the index and working tree still hold the staged changes
    git reset -q --soft "$head" || exit
    exit $rc
  ) || git_exit "Failed to stash unstaged changes"; }

  # miscellaneous
  # ----------------------------------------------------------------------------------

  __git_branches() {
    if [ -d .git ]; then
      echo "$(git branch -a | sed 's/^[* ]*//; s/remotes\///' | tr '\n' ' ' | xargs)"
    else
      echo ""
    fi
  }

  if command -v git-ver &> /dev/null; then
    complete -W "$(__git_branches)" git-merge
    complete -W "$(__git_branches)" git-merge-to
    complete -W "$(__git_branches)" git-reset
    complete -W "$(__git_branches)" git-resetf
    complete -W "$(__git_branches)" git-rebase
  fi

} # this ensures the entire script is downloaded #
