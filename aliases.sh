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

  # pick one of several remotes with the arrow keys (or j/k) and Enter; prints the choice
  git_choose_remote() {
    local remotes="$1" selected="${2:-1}" count key remote i saved
    count="$(printf '%s\n' "$remotes" | grep -c '')"
    saved="$(stty -g < /dev/tty)" || exit 1
    # read single keys without echo; put the terminal back however the menu ends
    trap 'stty "$saved" < /dev/tty; printf "\033[?25h\n" > /dev/tty; exit 130' INT TERM
    stty -echo -icanon min 1 time 0 < /dev/tty

    printf '==> Multiple Remotes Detected, choose one (up/down, Enter; q to cancel):\n\033[?25l' > /dev/tty
    while :; do
      i=0
      while IFS= read -r remote; do
        i=$((i + 1))
        if [[ $i -eq $selected ]]; then
          printf '\r\033[K  > %s\n' "$remote"
        else
          printf '\r\033[K    %s\n' "$remote"
        fi
      done <<< "$remotes" > /dev/tty

      key="$(dd bs=1 count=1 2> /dev/null < /dev/tty)"
      [[ $key == $'\033' ]] && key="$key$(dd bs=1 count=2 2> /dev/null < /dev/tty)"
      case "$key" in
      $'\033[A' | k) [[ $selected -gt 1 ]] && selected=$((selected - 1)) ;;
      $'\033[B' | j) [[ $selected -lt $count ]] && selected=$((selected + 1)) ;;
      '') break ;;
      q)
        selected=0
        break
        ;;
      esac
      printf '\033[%sA' "$count" > /dev/tty
    done

    # restore the terminal and clear the menu; the caller prints the choice
    stty "$saved" < /dev/tty
    printf '\033[%sA\r\033[J\033[?25h' "$((count + 1))" > /dev/tty
    [[ $selected -gt 0 ]] || exit 1
    printf '%s\n' "$remotes" | sed -n "${selected}p"
  }

  git_detect_remote() {
    if [[ -z $1 ]]; then
      _ORIGIN="$(git remote)"
      _LENGTH="$(git remote | wc -l)"
      if [[ $_LENGTH -eq 0 ]]; then
        echo >&2 "Error: This repository has no remotes."
        exit 1
      elif [[ $_LENGTH -eq 1 ]]; then
        git_echo "==> Detected Remote: $_ORIGIN"
      elif [ -t 0 ]; then
        # start on the current branch's upstream remote, else on origin
        local upstream
        upstream="$(git config "branch.$(git symbolic-ref --short -q HEAD).remote" || echo origin)"
        _ORIGIN="$(git_choose_remote "$_ORIGIN" "$(printf '%s\n' "$_ORIGIN" | grep -nxF -- "$upstream" | cut -d: -f1)")" || {
          git_echo "==> No remote chosen"
          exit 1
        }
        git_echo "==> Selected Remote: $_ORIGIN"
      else
        git_echo >&2 "==> Multiple Remotes Detected:"
        git_echo >&2 "$_ORIGIN"
        git_echo >&2 "==> Pass the remote to use as the first argument, e.g. git-push origin"
        exit 1
      fi
    else
      _ORIGIN="$1"
      git_echo "==> Requested Remote: $_ORIGIN"
    fi

    if [[ -z $2 ]]; then
      _BRANCH="$(git symbolic-ref --short -q HEAD)" || {
        echo >&2 "Error: Not on a branch (detached HEAD). Pass the branch to use as the second argument."
        exit 1
      }
      git_echo "==> Detected Branch: $_BRANCH"
    else
      _BRANCH="$2"
      git_echo "==> Requested Branch: $_BRANCH"
    fi
  }

  git_commit_lint() {
    local message_string="$1"
    # type(scope)!: description -- scope and ! are optional, description must not be blank
    local regex="^(build|chore|ci|docs|feat|fix|perf|refactor|revert|style|test)(\([^()]+\))?!?: [^[:space:]].*$"

    if [[ $message_string =~ $regex ]]; then
      echo ">> Your commit message adheres to the commit rules"
      echo
    else
      {
        echo
        echo "Oops! Your commit message does not conform to the commit rules."
        echo "Please ensure your commit message follows the conventional commits format:"
        echo "  type(scope)!: description"
        echo "Where:"
        echo "  - 'type' could be one of: build, chore, ci, docs, feat, fix, perf, refactor, revert, style, test"
        echo "  - 'scope' is optional and can be anything specifying the place of the commit change"
        echo "  - '!' is optional and marks a breaking change"
        echo "  - 'description' is a short description of the change"
      } >&2
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
    git_echo "v2.0-beta"
  ) || git_exit "Failed to retrieve git version"; }

  # long list of commit history
  git-ll() { (
    git log --abbrev-commit --decorate --pretty=format:"%C(yellow)%h %C(reset)-%C(red)%d %C(reset)%s %C(green)(%ar) %C(blue)[%an]" "$@"
  ) || git_exit "Failed to display commit history"; }

  # stage changes & commit
  git-it() { (
    git_commit_lint "$1"

    git add --all || exit
    git commit -m "$1"
  ) || git_exit "Failed to stage and commit changes"; }

  # commit changes & push
  git-up() { (
    git-it "$1" || exit
    git-push "${@:2}"
  ) || git_exit "Failed to commit and push changes"; }

  # modify last commit
  git-amend() { (
    [[ -z $1 ]] || git_commit_lint "$1"

    git add --all || exit
    if [[ -n $1 ]]; then
      git commit --amend --message="$1"
    else
      git commit --amend --no-edit
    fi
  ) || git_exit "Failed to amend the last commit"; }

  # modify last commit with current time
  git-amend-now() { (
    [[ -z $1 ]] || git_commit_lint "$1"

    git add --all || exit
    if [[ -n $1 ]]; then
      git commit --amend --reset-author --message="$1"
    else
      git commit --amend --reset-author --no-edit
    fi
  ) || git_exit "Failed to amend the last commit with the current time"; }

  # push changes to remote
  git-push() { (
    git_detect_remote "${@:1:2}"

    git push "${_ORIGIN}" "${_BRANCH}" "${@:3}"
  ) || git_exit "Failed to push changes"; }

  # push changes forcefully to remote
  git-pushf() { (
    git_detect_remote "${@:1:2}"

    git push --force-with-lease --force-if-includes "${_ORIGIN}" "${_BRANCH}" "${@:3}"
  ) || git_exit "Failed to force push changes"; }

  # pull changes from remote
  git-pull() { (
    git_detect_remote "${@:1:2}"

    git pull "${_ORIGIN}" "${_BRANCH}" "${@:3}"
  ) || git_exit "Failed to pull changes"; }

  # update local code as per remote
  git-pullf() { (
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
    git clean -df :/ || exit

    git_echo
    git_echo "==> Git Repository Cleared"
    git_echo
  ) || git_exit "Failed to clear the git repository"; }

  # sync everything
  git-sync() { (
    git_detect_remote "${@:1:2}"

    # stash local changes, noting whether a new stash entry was actually created
    before="$(git rev-parse -q --verify refs/stash)"
    git stash push --include-untracked || exit
    after="$(git rev-parse -q --verify refs/stash)"

    git fetch --all &&
      git checkout "$_BRANCH" &&
      git reset --hard "$_ORIGIN/$_BRANCH" &&
      git remote prune "$_ORIGIN"
    rc=$?

    # bring local changes back even if syncing stopped part-way
    if [[ $after != "$before" ]]; then
      git stash pop || {
        git_echo "==> Your local changes are kept in stash@{0}"
        exit 1
      }
    fi
    [[ $rc -eq 0 ]] || exit $rc

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
    # a remote as the first argument means "fix HEAD and push there"
    if [[ -n $1 ]] && git remote | grep -qxF -- "$1"; then
      git-fixit || exit
      git-push "$@"
    else
      git-fixit "$1" || exit
      git-push "${@:2}"
    fi
  ) || git_exit "Failed to fixup and push changes"; }

  # rebase all commit automatically
  git-rebase() { (
    GIT_SEQUENCE_EDITOR=true GIT_EDITOR=true git rebase --interactive --autosquash --autostash --rebase-merges --no-fork-point "$@"
  ) || git_exit "Failed to rebase commits"; }

  # add merge
  git-merge() { (
    if [[ -z $1 ]]; then
      echo >&2 "Error: No branch specified."
      exit 1
    fi

    current_branch=$(git rev-parse --abbrev-ref HEAD) || exit

    if [[ $current_branch == "$1" ]]; then
      echo >&2 "Error: You cannot merge into the same branch you are currently on."
      exit 1
    fi

    if [[ -n $2 ]]; then
      git merge "$1" --no-ff --no-edit -m "$2"
    else
      git merge "$1" --no-ff --no-edit --log
    fi
  ) || git_exit "Failed to merge branch"; }

  git-merge-to() { (
    if [[ -z $1 ]]; then
      echo >&2 "Error: No branch specified."
      exit 1
    fi

    current_branch=$(git rev-parse --abbrev-ref HEAD) || exit

    if [[ $current_branch == "$1" ]]; then
      echo >&2 "Error: You cannot merge into the same branch you are currently on."
      exit 1
    fi

    git checkout "$1" || exit
    if [[ -n $2 ]]; then
      git merge "$current_branch" --no-ff --no-edit -m "$2"
    else
      git merge "$current_branch" --no-ff --no-edit --log
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

  # complete local and remote branch names, looked up at completion time
  __git_aliases_complete_branches() {
    # shellcheck disable=SC2207
    COMPREPLY=($(compgen -W "$(git for-each-ref --format='%(refname:short)' refs/heads refs/remotes 2> /dev/null)" -- "${COMP_WORDS[COMP_CWORD]}"))
  }

  # bash-style completion; zsh only has `complete` after `bashcompinit`
  if command -v complete &> /dev/null; then
    complete -F __git_aliases_complete_branches git-merge git-merge-to git-reset git-resetf git-rebase
  fi

} # this ensures the entire script is downloaded #
