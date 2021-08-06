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
        echo "==> Exiting to another space, there seems to be an error.";
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

# aliases
# ----------------------------------------------------------------------------------

git-aliases() {( set -e  #fail early
# <try>
    git_echo "git-aliases is at $(git-ver)"
# <end>
) || git_exit; }


git-ver() {( set -e  #fail early
# <try>
    git_echo "v1.0.2-beta"
# <end>
) || git_exit; }


git-ll() {( set -e  #fail early
# <try>
    git log --abbrev-commit --decorate --pretty=format:"%C(yellow)%h %C(reset)-%C(red)%d %C(reset)%s %C(green)(%ar) %C(blue)[%an]" "$@"
# <end>
) || git_exit; }


git-it() {( set -e  #fail early
# <try>
    local _MESSAGE="$1"

    git add --all
    git commit -m "$_MESSAGE"
# <end>
) || git_exit; }


git-up() {( set -e  #fail early
# <try>
    git-it "$1"
    git-push "${@:2}"
# <end>
) || git_exit; }


git-amend() {( set -e  #fail early
# <try>
    git add --all
  
    if [[ -n "$1" ]]; then
        git commit --amend --reset-author --message="$1";
    else
        git commit --amend --reset-author --no-edit;
    fi;
    # in case to modify date: git commit --amend --date="$(date -R)"
# <end>
) || git_exit; }


git-push() {( set -e  #fail early
# <try>
    if [[ -z "$1" ]]; then local _ORIGIN; fi
    if [[ -z "$2" ]]; then local _BRANCH; fi
    git_detect_remote "${@:1:2}"

    git push "${_ORIGIN}" "${_BRANCH}" "${@:3}"
# <end>
) || git_exit; }


git-pushf() {( set -e  #fail early
# <try>
    if [[ -z "$1" ]]; then local _ORIGIN; fi
    if [[ -z "$2" ]]; then local _BRANCH; fi
    git_detect_remote "${@:1:2}"

    git push --force "${_ORIGIN}" "${_BRANCH}" "${@:3}"
# <end>
) || git_exit; }


git-pull() {( set -e  #fail earlyy
# <try>
    if [[ -z "$1" ]]; then local _ORIGIN; fi
    if [[ -z "$2" ]]; then local _BRANCH; fi
    git_detect_remote "${@:1:2}"

    git pull "${_ORIGIN}" "${_BRANCH}" "${@:3}"
# <end>
) || git_exit; }


git-pullf() {( set -e  #fail early
# <try>
    if [[ -z "$1" ]]; then local _ORIGIN; fi
    if [[ -z "$2" ]]; then local _BRANCH; fi
    git_detect_remote "${@:1:2}"

    git fetch --all
    git reset --hard "$_ORIGIN/$_BRANCH"
# <end>
) || git_exit; }


git-sync() {( set -e  #fail early
# <try>
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
# <end>
) || git_exit; }


git-clean() {( set -e  #fail early
# <try>
    if [[ -n "$1" ]]; then
        git reflog expire --expire-unreachable=now --all;
    else
        git gc --prune=now --aggressive;
    fi;

    git_echo
    git_echo "==> Git Repository Cleaned"
    git_echo
# <end>
) || git_exit; }


git-clear() {( set -e  #fail early
# <try>
    git reset --hard
    git clean -df

    git_echo
    git_echo "==> Git Repository Cleared"
    git_echo
# <end>
) || git_exit; }


git-fixit() {( set -e  #fail early
# <try>
    local _HASH="${1:-HEAD}"

    # Get a commit ref (long-hash-id)
    _HASH="$(git rev-parse "$_HASH")"

    git add --all
    git commit --no-verify --fixup "$_HASH"
# <end>
) || git_exit; }


git-fixup() {( set -e  #fail early
# <try>
    git-fixit "$1"
    git-push "${@:2}"
# <end>
) || git_exit; }


git-rebase() {( set -e  #fail early
# <try>
    EDITOR=true git rebase --interactive --autosquash --autostash --rebase-merges --no-fork-point "$@"
# <end>
) || git_exit; }


git-merge() {( set -e  #fail early
# <try>
    if [[ -z "$1" ]]; then exit 1; fi

    if [[ -n "$2" ]]; then
        EDITOR=true git merge "$1" --no-ff -m "$2";
    else
        EDITOR=true git merge "$1" --no-ff --log;
    fi;
# <end>
) || git_exit; }


# miscellaneous
# ----------------------------------------------------------------------------------

__git_branches() {
  echo "$(git branch -a | tr '\n' ' ')";
}

complete -W "$(__git_branches)" git-merge


} # this ensures the entire script is downloaded #
