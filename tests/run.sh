#!/usr/bin/env bash
# Test suite for aliases.sh and install.sh
#
#   tests/run.sh [--shell bash|zsh] [area]
#
# Every alias runs in a fresh `bash -c` (or `zsh -f -c`) that sources aliases.sh, in
# throwaway repos under one temp dir; $HOME and git's config are isolated from yours.
# Needs git. python3 drives the terminal tests (remote picker, merge editor) and serves
# files for the installer tests; curl and/or wget are needed for the installer tests.
# Anything whose tool is missing is skipped, not failed.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ALIASES="$ROOT/aliases.sh"
INSTALL="$ROOT/install.sh"
SHELL_NAME=bash
FILTER=

while [ $# -gt 0 ]; do
  case "$1" in
  --shell)
    SHELL_NAME="$2"
    shift 2
    ;;
  *)
    FILTER="$1"
    shift
    ;;
  esac
done
case "$SHELL_NAME" in
bash) SHELL_CMD=(bash) ;;
zsh) SHELL_CMD=(zsh -f) ;;
*)
  echo "unknown shell: $SHELL_NAME" >&2
  exit 2
  ;;
esac
command -v "${SHELL_CMD[0]}" > /dev/null || {
  echo "$SHELL_NAME is not installed" >&2
  exit 2
}

TMP="$(mktemp -d)" || exit 1
trap 'rm -rf "$TMP"' EXIT

# isolate from the user's home, git config, identity and editors
export HOME="$TMP/home" HISTFILE=
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
unset GIT_EDITOR GIT_SEQUENCE_EDITOR VISUAL EDITOR
mkdir -p "$HOME"

pass=0
fail=0
skipped=0

# check <name> <got> <expected>
check() {
  if [ "$2" = "$3" ]; then
    pass=$((pass + 1))
    printf 'ok   %s\n' "$1"
  else
    fail=$((fail + 1))
    printf 'FAIL %s\n       expected: %s\n       got:      %s\n' "$1" "$3" "$2"
  fi
}

skip() {
  skipped=$((skipped + 1))
  printf 'skip %s (%s)\n' "$1" "$2"
}

# ga <alias> [args...]: run an alias in a fresh shell that sources aliases.sh
ga() {
  # shellcheck disable=SC2016
  "${SHELL_CMD[@]}" -c 'source "$1" > /dev/null 2>&1; shift; "$@"' ga "$ALIASES" "$@"
}

has() {
  command -v "$1" > /dev/null 2>&1
}

# --- fixtures ----------------------------------------------------------------------

# new_repo <dir>: a repo with one commit on main
new_repo() {
  git init -q -b main "$1" && git -C "$1" commit -q --allow-empty -m "chore: init"
}

# with_remote <dir>: <dir>/remote.git plus a clone <dir>/repo with main pushed
with_remote() {
  git init -q --bare -b main "$1/remote.git"
  git clone -q "$1/remote.git" "$1/repo" 2> /dev/null
  git -C "$1/repo" commit -q --allow-empty -m "chore: init"
  git -C "$1/repo" push -q -u origin main 2> /dev/null
  git -C "$1/repo" remote set-head -a origin > /dev/null
}

# remote_head <bare repo> [branch]
remote_head() {
  git --git-dir="$1" rev-parse -q --verify "${2:-main}"
}

# lines <n>: "line 1" .. "line n"
lines() {
  local i=1
  while [ "$i" -le "$1" ]; do
    echo "line $i"
    i=$((i + 1))
  done
}

# set_line <file> <old line> <new line>
set_line() {
  awk -v o="$2" -v n="$3" '$0 == o { $0 = n } { print }' "$1" > "$1.tmp" && mv "$1.tmp" "$1"
}

# everything the user has in a work tree, as one comparable string
snapshot() {
  git diff --cached --binary | grep -v '^index '
  echo "=="
  git diff --binary | grep -v '^index '
  echo "=="
  git ls-files -o --exclude-standard | sort | while IFS= read -r f; do
    printf '%s ' "$f"
    cksum < "$f"
  done
}

# --- areas ---------------------------------------------------------------------------

t_basics() {
  cd "$TMP" || return
  check "sourcing aliases.sh prints nothing" "$("${SHELL_CMD[@]}" -c 'source "$1"; echo "rc=$?"' _ "$ALIASES" 2>&1)" "rc=0"
  check "git-aliases shows git-ver" "$(ga git-aliases)" "git-aliases is at $(ga git-ver)"
}

t_errors() {
  local d="$TMP/errors" before
  mkdir -p "$d" && with_remote "$d" && cd "$d/repo" || return
  git commit -q --allow-empty -m "feat: unpushed"
  before="$(remote_head ../remote.git)"
  echo a > a.txt
  ga git-up "wip" > /dev/null 2>&1
  check "git-up 'wip': exit 1" "$?" 1
  check "git-up 'wip': nothing pushed" "$(remote_head ../remote.git)" "$before"
  ga git-up "feat: add a" > /dev/null 2>&1
  check "git-up 'feat: add a': exit 0" "$?" 0
  check "git-up 'feat: add a': pushed" "$(remote_head ../remote.git)" "$(git rev-parse HEAD)"
  git commit -q --allow-empty -m "feat: unpushed 2"
  before="$(remote_head ../remote.git)"
  echo b > b.txt
  ga git-fixup nosuchref > /dev/null 2>&1
  check "git-fixup <bad ref>: fails" "$([ $? -ne 0 ] && echo failed)" failed
  check "git-fixup <bad ref>: nothing pushed" "$(remote_head ../remote.git)" "$before"
  git reset -q && rm -f b.txt
  ga git-merge-to nosuchbranch > /dev/null 2>&1
  check "git-merge-to <missing>: exit 1" "$?" 1
  check "git-merge-to <missing>: still on main" "$(git rev-parse --abbrev-ref HEAD)" main
  check "git-it with nothing to commit: '&&' chain stops" "$(ga git-it "feat: nothing" > /dev/null 2>&1 && echo continued || echo stopped)" stopped
  check "failure banner goes to stderr" "$({ ga git-merge-to nosuchbranch > /dev/null; } 2>&1 | grep -c '==> Failed')" 1
}

# stash_fixture <dir> <separate|overlap|binary>: a repo with staged + unstaged changes
stash_fixture() {
  new_repo "$1" && cd "$1" || return
  lines 20 > f.txt
  printf 'bin\000base' > bin.dat
  printf 'bin\000base2' > bin2.dat
  mkdir sub && echo s > sub/s.txt
  git add . && git commit -q -m "chore: base"
  case "$2" in
  separate)
    set_line f.txt "line 2" "line 2 STAGED" && git add f.txt
    set_line f.txt "line 18" "line 18 UNSTAGED"
    echo new > new.txt && git add new.txt
    echo junk > untracked.txt
    ;;
  overlap)
    set_line f.txt "line 5" "line 5 STAGED" && git add f.txt
    set_line f.txt "line 5 STAGED" "line 5 BOTH"
    ;;
  binary)
    printf 'bin\000staged' > bin.dat && git add bin.dat
    printf 'bin\000unstaged' > bin2.dat
    set_line f.txt "line 9" "line 9 UNSTAGED"
    ;;
  esac
}

t_stash() {
  local c staged unstaged before want
  for c in separate binary subdir; do
    stash_fixture "$TMP/sstash-$c" "${c/subdir/separate}" || return
    staged="$(git diff --cached --binary | grep -v '^index ')"
    unstaged="$(git diff --binary | grep -v '^index ')"
    if [ "$c" = subdir ]; then
      (cd sub && ga git-sstash > /dev/null 2>&1)
    else
      ga git-sstash > /dev/null 2>&1
    fi
    check "git-sstash ($c): exit 0" "$?" 0
    check "git-sstash ($c): stash holds exactly the staged changes" "$(git diff --binary 'stash@{0}^1' 'stash@{0}' | grep -v '^index ')" "$staged"
    check "git-sstash ($c): nothing left staged" "$(git diff --cached --name-only)" ""
    check "git-sstash ($c): unstaged changes kept" "$(git diff --binary | grep -v '^index ')" "$unstaged"
  done
  check "git-sstash: untracked files stay" "$([ -f "$TMP/sstash-separate/untracked.txt" ] && echo yes)" yes

  stash_fixture "$TMP/sstash-overlap" overlap || return
  before="$(snapshot)"
  ga git-sstash > /dev/null 2>&1
  check "git-sstash (overlapping edits): exit 1" "$?" 1
  check "git-sstash (overlapping edits): no stash entry" "$(git stash list)" ""
  check "git-sstash (overlapping edits): work tree untouched" "$(snapshot)" "$before"

  for c in separate overlap binary subdir; do
    stash_fixture "$TMP/nstash-$c" "${c/subdir/separate}" || return
    before="$(snapshot)"
    staged="$(git diff --cached --binary | grep -v '^index ')"
    if [ "$c" = subdir ]; then
      (cd sub && ga git-nstash > /dev/null 2>&1)
    else
      ga git-nstash > /dev/null 2>&1
    fi
    check "git-nstash ($c): exit 0" "$?" 0
    check "git-nstash ($c): staged changes kept" "$(git diff --cached --binary | grep -v '^index ')" "$staged"
    check "git-nstash ($c): nothing unstaged or untracked left" "$(
      git diff --name-only
      git ls-files -o --exclude-standard
    )" ""
    git stash pop -q --index 2> /dev/null
    check "git-nstash ($c): 'git stash pop --index' restores everything" "$(snapshot)" "$before"
  done

  stash_fixture "$TMP/nstash-commit" overlap || return
  want="$(cat f.txt)"
  ga git-nstash > /dev/null 2>&1
  git commit -q -m "feat: staged part"
  git stash pop -q 2> /dev/null
  check "git-nstash: pops cleanly after committing the staged part" "$?:$(cat f.txt)" "0:$want"
}

t_sync() {
  local d
  # sync_fixture <dir>: remote + my clone + a teammate's clone, all on one commit
  sync_fixture() {
    mkdir -p "$1"
    git init -q --bare -b main "$1/remote.git"
    git clone -q "$1/remote.git" "$1/mate" 2> /dev/null
    (cd "$1/mate" && lines 9 > f.txt && git add . && git commit -q -m "chore: init" && git push -q origin main 2> /dev/null)
    git clone -q "$1/remote.git" "$1/repo" 2> /dev/null
    cd "$1/repo" || return
  }
  mate_pushes() {
    (cd ../mate && set_line f.txt "line $1" "line $1 remote" && git commit -qam "feat: remote $1" && git push -q origin main 2> /dev/null)
  }

  d="$TMP/sync-clean" && sync_fixture "$d" || return
  echo old > g.txt && git stash push -q -u -m "unrelated work"
  ga git-sync > /dev/null 2>&1
  check "git-sync, clean tree + old stash: exit 0" "$?" 0
  check "git-sync, clean tree + old stash: old stash left alone" "$(git stash list | wc -l | tr -d ' '):$([ -e g.txt ] && echo applied || echo absent)" "1:absent"

  d="$TMP/sync-edits" && sync_fixture "$d" || return
  mate_pushes 9
  set_line f.txt "line 1" "line 1 local" && echo u > untracked.txt
  ga git-sync > /dev/null 2>&1
  check "git-sync, local edits: exit 0" "$?" 0
  check "git-sync, local edits: synced to the remote" "$(git rev-parse HEAD)" "$(git rev-parse origin/main)"
  check "git-sync, local edits: edits back, untracked stays untracked" "$(grep -c 'line 1 local' f.txt):$(git status --short untracked.txt)" "1:?? untracked.txt"

  d="$TMP/sync-fetch" && sync_fixture "$d" || return
  set_line f.txt "line 1" "line 1 local"
  git remote set-url origin "$d/missing.git"
  ga git-sync > /dev/null 2>&1
  check "git-sync, fetch fails: non-zero exit, edits restored" "$([ $? -ne 0 ] && echo failed):$(grep -c 'line 1 local' f.txt):$(git stash list | wc -l | tr -d ' ')" "failed:1:0"

  d="$TMP/sync-nosuch" && sync_fixture "$d" || return
  set_line f.txt "line 1" "line 1 local"
  ga git-sync origin nosuch > /dev/null 2>&1
  check "git-sync origin <missing branch>: exit 1, edits restored" "$?:$(grep -c 'line 1 local' f.txt):$(git rev-parse --abbrev-ref HEAD)" "1:1:main"

  d="$TMP/sync-conflict" && sync_fixture "$d" || return
  mate_pushes 1
  set_line f.txt "line 1" "line 1 local"
  check "git-sync, conflicting edit: says it's kept in stash@{0}" "$(ga git-sync 2>&1 | grep -c 'kept in stash')" 1
  check "git-sync, conflicting edit: stash kept" "$(git stash list | wc -l | tr -d ' ')" 1
}

t_fixup() {
  local args d want n=0
  for args in "" "origin" "origin main" "HEAD~1" "HEAD~1 origin main"; do
    n=$((n + 1))
    d="$TMP/fixup-$n" && mkdir -p "$d" && with_remote "$d" && cd "$d/repo" || return
    git commit -q --allow-empty -m "feat: two" && git push -q 2> /dev/null
    git commit -q --allow-empty -m "feat: three"
    echo change > c.txt
    # shellcheck disable=SC2086
    ga git-fixup $args > /dev/null 2>&1
    case "$args" in
    HEAD~1*) want="fixup! feat: two" ;;
    *) want="fixup! feat: three" ;;
    esac
    check "git-fixup $args: fixes the right commit and pushes" "$?:$(git log -1 --format=%s):$([ "$(remote_head ../remote.git)" = "$(git rev-parse HEAD)" ] && echo pushed)" "0:$want:pushed"
  done
}

t_editor() {
  local d how
  # rebase_fixture <dir> <fixup|squash>: three commits, the last one a fixup!/squash! of the first
  rebase_fixture() {
    new_repo "$1" && cd "$1" || return
    echo a > a.txt && git add a.txt && git commit -q -m "feat: a"
    echo b > b.txt && git add b.txt && git commit -q -m "feat: b"
    echo a2 >> a.txt && git add a.txt && git commit -q -m "$2! feat: a"
  }
  for how in core.editor sequence.editor GIT_EDITOR squash; do
    d="$TMP/rebase-$how"
    case "$how" in
    squash) rebase_fixture "$d" squash && git config core.editor false ;;
    GIT_EDITOR) rebase_fixture "$d" fixup ;;
    *) rebase_fixture "$d" fixup && git config "$how" false ;;
    esac
    if [ "$how" = GIT_EDITOR ]; then
      GIT_EDITOR=false ga git-rebase HEAD~3 > /dev/null 2>&1
    else
      ga git-rebase HEAD~3 > /dev/null 2>&1
    fi
    check "git-rebase with a failing editor ($how): squashes without opening it" "$?:$(git rev-list --count HEAD)" "0:3"
  done

  if ! has python3; then
    skip "git-merge / git-merge-to in a terminal" "python3 missing"
    return
  fi
  for how in git-merge git-merge-to GIT_EDITOR; do
    d="$TMP/merge-$how"
    new_repo "$d" && cd "$d" || return
    git checkout -q -b feature && echo f > f.txt && git add f.txt && git commit -q -m "feat: f"
    case "$how" in
    git-merge-to) git config core.editor false ;;
    git-merge) git checkout -q main && git config core.editor false ;;
    GIT_EDITOR) git checkout -q main ;;
    esac
    if [ "$how" = git-merge-to ]; then
      python3 "$ROOT/tests/term.py" run -- "${SHELL_CMD[@]}" -c 'source "$1" > /dev/null 2>&1; git-merge-to main' _ "$ALIASES" > /dev/null
    elif [ "$how" = GIT_EDITOR ]; then
      GIT_EDITOR=false python3 "$ROOT/tests/term.py" run -- "${SHELL_CMD[@]}" -c 'source "$1" > /dev/null 2>&1; git-merge feature' _ "$ALIASES" > /dev/null
    else
      python3 "$ROOT/tests/term.py" run -- "${SHELL_CMD[@]}" -c 'source "$1" > /dev/null 2>&1; git-merge feature' _ "$ALIASES" > /dev/null
    fi
    check "$how in a terminal with a failing editor: merges without opening it" "$(git log --format=%s main | grep -c '^Merge branch')" 1
  done
}

t_lint() {
  local m want got
  while IFS='|' read -r want m; do
    m="${m//\\n/$'\n'}"
    m="${m//\\s/ }"
    got="$(ga git_commit_lint "$m" > /dev/null 2>&1 && echo pass || echo reject)"
    check "lint: \"${m//$'\n'/\\n}\"" "$got" "$want"
  done << 'EOF'
pass|feat: add login
pass|test: add bats suite
pass|feat(git-aliases): add git-ver
pass|fix(api/v2): handle 404
pass|docs(README.md): fix typo
pass|feat!: drop git < 2.30
pass|feat(api)!: remove v1 endpoints
pass|feat: x\n\nlonger body text
reject|feat:\s
reject|feat:\s\s\s\s
reject|feat:x
reject|feat(): x
reject|Feat: add login
reject|wip
EOF

  new_repo "$TMP/lint" && cd "$TMP/lint" || return
  echo a > a.txt && git add a.txt && git commit -q -m "chore: a"
  for m in git-it git-amend git-amend-now; do
    echo change >> a.txt && echo new > untracked.txt
    ga "$m" "wip" > /dev/null 2>&1
    check "$m 'wip': rejected before anything is staged" "$?:$(git diff --cached --name-only)" "1:"
    git checkout -q -- a.txt && rm -f untracked.txt
  done
  echo b > b.txt
  ga git-it "test: add b" > /dev/null 2>&1
  check "git-it 'test: add b': commits" "$?:$(git log -1 --format=%s)" "0:test: add b"
  check "git-it/git-amend-now lint text goes to stderr" "$(ga git-it wip 2> /dev/null)" ""
}

t_pushf() {
  local d n=0 how
  for how in alone unfetched background integrated newbranch; do
    n=$((n + 1))
    d="$TMP/pushf-$n" && mkdir -p "$d" && with_remote "$d" || return
    git clone -q "$d/remote.git" "$d/mate" 2> /dev/null
    cd "$d/repo" || return
    case "$how" in
    unfetched | background | integrated)
      (cd ../mate && git commit -q --allow-empty -m "feat: mate" && git push -q origin main 2> /dev/null)
      ;;
    esac
    case "$how" in
    background) git fetch -q ;;
    integrated) git pull -q --rebase 2> /dev/null && git commit -q --allow-empty -m "feat: mine" && git push -q 2> /dev/null ;;
    esac
    if [ "$how" = newbranch ]; then
      git checkout -q -b topic && git commit -q --allow-empty -m "feat: topic"
      ga git-pushf origin topic > /dev/null 2>&1
      check "git-pushf, first push of a new branch: pushed" "$?:$([ "$(remote_head ../remote.git topic)" = "$(git rev-parse HEAD)" ] && echo yes)" "0:yes"
      continue
    fi
    git commit -q --amend --allow-empty -m "$(git log -1 --format=%s) (amended)"
    ga git-pushf > /dev/null 2>&1
    case "$how" in
    alone | integrated)
      check "git-pushf ($how): pushed" "$?:$([ "$(remote_head ../remote.git)" = "$(git rev-parse HEAD)" ] && echo yes)" "0:yes"
      ;;
    *)
      check "git-pushf ($how): refused, teammate's commit kept" "$([ $? -ne 0 ] && echo refused):$(git --git-dir=../remote.git log --format=%s main | grep -c 'feat: mate')" "refused:1"
      ;;
    esac
    [ "$how" = integrated ] && check "git-pushf (integrated): teammate's commit kept" "$(git --git-dir=../remote.git log --format=%s main | grep -c 'feat: mate')" 1
  done
}

t_remote() {
  local d out
  # remotes_fixture <dir> <remote...>: a repo with these (empty) remotes
  remotes_fixture() {
    local dir="$1" r
    shift
    new_repo "$dir/repo" || return
    for r in "$@"; do
      git init -q --bare -b main "$dir/$r.git" && git -C "$dir/repo" remote add "$r" "$dir/$r.git"
    done
    cd "$dir/repo" || return
  }
  pushed_to() {
    local r got=
    for r in fork origin upstream; do
      [ -d "../$r.git" ] && remote_head "../$r.git" > /dev/null && got="$got$r "
    done
    echo "${got:-none}"
  }

  d="$TMP/remote-notty" && remotes_fixture "$d" origin upstream fork || return
  out="$({ ga git-push < /dev/null > /dev/null; } 2>&1)"
  check "several remotes, no terminal: exit 1 with a hint on stderr" "$(
    ga git-push < /dev/null > /dev/null 2>&1
    echo $?
  ):$(echo "$out" | grep -c 'first argument')" "1:1"
  ga git-push fork < /dev/null > /dev/null 2>&1
  check "several remotes, 'git-push fork': pushes there without asking" "$?:$(pushed_to)" "0:fork "

  d="$TMP/remote-one" && remotes_fixture "$d" origin || return
  ga git-push < /dev/null > /dev/null 2>&1
  check "one remote: pushes there" "$?:$(pushed_to)" "0:origin "

  d="$TMP/remote-none" && remotes_fixture "$d" || return
  check "no remotes: says so on stderr" "$({ ga git-push > /dev/null; } 2>&1 | grep -c 'no remotes')" 1

  d="$TMP/remote-detached" && remotes_fixture "$d" origin || return
  git checkout -q --detach
  check "detached HEAD: says so on stderr" "$({ ga git-push origin > /dev/null; } 2>&1 | grep -c 'detached HEAD')" 1
  ga git-push origin main > /dev/null 2>&1
  check "detached HEAD with the branch given: pushes" "$?:$(pushed_to)" "0:origin "

  if ! has python3; then
    skip "remote picker" "python3 missing"
    return
  fi
  # picker <name> <tracked remote|-> <keys> <want>
  picker() {
    local name="$1" tracked="$2" keys="$3" want="$4" res
    d="$TMP/picker-$name" && remotes_fixture "$d" origin upstream fork || return
    [ "$tracked" != - ] && git config branch.main.remote "$tracked"
    res="$(python3 "$ROOT/tests/term.py" shell --shell "$SHELL_NAME" --source "$ALIASES" --cmd git-push --expect "choose one" --keys "$keys" | head -1)"
    check "picker ($name): $want" "$res:$(pushed_to)" "$want"
  }
  # git remote lists fork, origin, upstream; the highlight starts on the upstream remote, else origin
  picker enter-tracked upstream ENTER "rc=0 menu=yes tty=restored:upstream "
  picker enter-default - ENTER "rc=0 menu=yes tty=restored:origin "
  picker down - DOWN,ENTER "rc=0 menu=yes tty=restored:upstream "
  picker clamp-bottom - DOWN,DOWN,DOWN,DOWN,ENTER "rc=0 menu=yes tty=restored:upstream "
  picker clamp-top fork UP,ENTER "rc=0 menu=yes tty=restored:fork "
  picker jk - j,j,k,ENTER "rc=0 menu=yes tty=restored:origin "
  picker cancel-q - q "rc=1 menu=yes tty=restored:none"
  picker ctrl-c - CTRL_C "rc=130 menu=yes tty=restored:none"
}

t_completion() {
  if [ "$SHELL_NAME" != bash ]; then
    skip "branch completion" "bash only"
    return
  fi
  local d="$TMP/completion"
  git init -q --bare -b main "$d/remote.git"
  git clone -q "$d/remote.git" "$d/a" 2> /dev/null
  (cd "$d/a" && mkdir sub && touch sub/x && git add . && git commit -q -m init && git branch feature &&
    git push -q origin main feature 2> /dev/null && git remote set-head -a origin > /dev/null &&
    git worktree add -q "$d/wt" -b feature2 2> /dev/null)
  new_repo "$d/b" && git -C "$d/b" branch other
  mkdir -p "$d/home"
  # complete_in <dir> <cmd> <word>: what <TAB> offers after sourcing the aliases outside any repo
  complete_in() {
    # shellcheck disable=SC2016
    (cd "$d/home" && bash -c 'source "$1" > /dev/null 2>&1; cd "$2" || exit
      fn="$(complete -p "$3" | sed -E "s/.* -F ([^ ]+) .*/\1/")"
      COMP_WORDS=("$3" "$4"); COMP_CWORD=1; COMPREPLY=()
      "$fn" "$3" "$4" "$3"; echo "${COMPREPLY[*]}"' _ "$ALIASES" "$1" "$2" "$3")
  }
  check "completion, repo root: git-merge fe" "$(complete_in "$d/a" git-merge fe)" "feature feature2"
  check "completion, remote branches: git-rebase origin/" "$(complete_in "$d/a" git-rebase origin/)" "origin/feature origin/main"
  check "completion, subdirectory: git-merge-to ma" "$(complete_in "$d/a/sub" git-merge-to ma)" "main"
  check "completion, linked worktree: git-reset fe" "$(complete_in "$d/wt" git-reset fe)" "feature feature2"
  check "completion, another repo: git-resetf ''" "$(complete_in "$d/b" git-resetf "")" "main other"
  check "completion, outside a repo: nothing, no errors" "$(complete_in "$d/home" git-merge "" 2>&1)" ""
  check "shell without 'complete': loads silently" "$(bash -c 'enable -n complete; source "$1"; echo "rc=$?"' _ "$ALIASES" 2>&1)" "rc=0"
}

t_misc() {
  local d="$TMP/clear"
  new_repo "$d" && cd "$d" || return
  mkdir sub && echo a > tracked.txt && touch sub/keep && git add . && git commit -q -m "chore: files"
  echo changed > tracked.txt && echo x > root-untracked.txt && echo y > sub/sub-untracked.txt
  (cd sub && ga git-clear > /dev/null 2>&1)
  check "git-clear from a subdirectory: whole repo cleared" "$(git status --short)" ""
  check "git-merge with no branch: error on stderr only" "$(ga git-merge 2> /dev/null):$({ ga git-merge > /dev/null; } 2>&1 | grep -c 'No branch')" ":1"
}

t_install() {
  if [ "$SHELL_NAME" != bash ]; then
    skip "installer" "runs under bash (curl | bash), so only checked with --shell bash"
    return
  fi
  local tools="$TMP/tools" d port srv="" home out
  # fake_path <name> [tool...]: a PATH with the basics plus the given tools
  fake_path() {
    local dir="$tools/$1" t
    shift
    mkdir -p "$dir"
    for t in sed grep chmod sort cat rm mkdir mktemp mv touch "$@"; do
      ln -sf "$(command -v "$t")" "$dir/$t"
    done
    printf %s "$dir"
  }
  # inst <home> <PATH> <source url> [env...]: run the installer like `curl | bash`
  inst() {
    local h="$1" p="$2" src="$3"
    shift 3
    (cd "$h" && env -i HOME="$h" PATH="$p" SHELL="${INST_SHELL:-/bin/bash}" XYZ_SOURCE="$src" "$@" "$(command -v bash)" "$INSTALL" 2>&1)
  }
  # profile_line <file>: the path the profile sources, with $HOME shown as ~
  sourced() {
    grep -o '\. "[^"]*"' "$2" 2> /dev/null | sed "s|$1|~|"
  }
  if ! has curl; then
    skip "installer" "curl missing"
    return
  fi
  local curl_path none_path ok_src="file://$ALIASES"
  curl_path="$(fake_path curl curl)"
  none_path="$(fake_path none)"

  home="$TMP/i-ok" && mkdir -p "$home" && touch "$home/.bashrc"
  inst "$home" "$curl_path" "$ok_src" > /dev/null
  check "install: exit 0, file installed, profile sources it" "$?:$([ -s "$home/.git_aliases" ] && echo yes):$(sourced "$home" "$home/.bashrc")" '0:yes:. "~/.git_aliases"'
  inst "$home" "$curl_path" "$ok_src" > /dev/null
  check "install twice: source line added once" "$(grep -c 'loads git_aliases' "$home/.bashrc")" 1
  check "install: file is readable and executable" "$([ -r "$home/.git_aliases" ] && [ -x "$home/.git_aliases" ] && echo yes)" yes

  home="$TMP/i-404" && mkdir -p "$home" && touch "$home/.bashrc"
  out="$(inst "$home" "$curl_path" "file://$TMP/nope.sh")"
  check "download fails: exit 1, profile untouched, no success message" "$?:$(wc -c < "$home/.bashrc" | tr -d ' '):$(echo "$out" | grep -c 'Close and reopen')" "1:0:0"
  home="$TMP/i-none" && mkdir -p "$home" && touch "$home/.bashrc"
  out="$(inst "$home" "$none_path" "$ok_src")"
  check "no curl and no wget: exit 1, says so" "$?:$(echo "$out" | grep -c 'You need curl, or wget')" "1:1"

  home="$TMP/i-keep" && mkdir -p "$home" && echo "# old install" > "$home/.git_aliases"
  inst "$home" "$curl_path" "file://$TMP/nope.sh" > /dev/null
  check "failed update (curl): old install kept" "$(cat "$home/.git_aliases")" "# old install"

  # profile <name> <SHELL> <files> <want> [env...]
  profile() {
    local name="$1" sh="$2" files="$3" want="$4" f got
    shift 4
    home="$TMP/p-$name" && mkdir -p "$home"
    for f in $files; do mkdir -p "$(dirname "$home/$f")" && touch "$home/$f"; done
    INST_SHELL="$sh" inst "$home" "$curl_path" "$ok_src" "${@//__HOME__/$home}" > /dev/null
    got="$(cd "$home" && grep -rl --include='.*' 'loads git_aliases' . 2> /dev/null | sed 's|^\./||' | tr '\n' ' ')"
    check "profile ($name): line added to $want" "$got" "$want "
  }
  profile zsh-both /bin/zsh ".bashrc .zshrc" .zshrc
  profile zsh-bash_profile /bin/zsh ".bash_profile" .zshrc
  profile zsh-fresh /bin/zsh "" .zshrc
  profile zsh-zdotdir /bin/zsh ".bashrc .config/zsh/.zshrc" .config/zsh/.zshrc ZDOTDIR=__HOME__/.config/zsh
  profile bash /bin/bash ".bashrc .zshrc" .bashrc
  profile fish /usr/bin/fish ".profile .bashrc" .bashrc
  profile custom /bin/zsh ".zshrc .custom" .custom PROFILE=__HOME__/.custom

  # location <name> <want> [env...]
  location() {
    local name="$1" want="$2"
    shift 2
    home="$TMP/l-$name" && mkdir -p "$home/.config" "$home/tools" && touch "$home/.bashrc"
    inst "$home" "$curl_path" "$ok_src" "${@//__HOME__/$home}" > /dev/null
    check "location ($name)" "$?:$(sourced "$home" "$home/.bashrc")" "$want"
  }
  location default '0:. "~/.git_aliases"'
  location xdg '0:. "~/.config/.git_aliases"' XDG_CONFIG_HOME=__HOME__/.config
  location xyz_path '0:. "~/tools/aliases.sh"' XYZ_PATH=__HOME__/tools/aliases.sh
  location both '0:. "~/tools/aliases.sh"' XYZ_PATH=__HOME__/tools/aliases.sh XDG_CONFIG_HOME=__HOME__/.config
  location dir '1:' XYZ_PATH=__HOME__/tools
  location missing-dir '1:' XYZ_PATH=__HOME__/missing/aliases.sh
  location percent '0:. "~/tools/50%done.sh"' XYZ_PATH=__HOME__/tools/50%done.sh

  home="$TMP/i-regex" && mkdir -p "$home/tools"
  printf '[ -s "%s" ] && . "%s"\n' "$home/tools/aXb.sh" "$home/tools/aXb.sh" > "$home/.bashrc"
  inst "$home" "$curl_path" "$ok_src" XYZ_PATH="$home/tools/a.b.sh" > /dev/null
  check "path with regex characters: source line still added" "$(grep -cF "$home/tools/a.b.sh" "$home/.bashrc")" 1

  home="$TMP/i-tried" && mkdir -p "$home"
  check 'missing $PROFILE is named in the message' "$(inst "$home" "$curl_path" "$ok_src" PROFILE="$home/.myprofile" | grep -c "Tried $home/.myprofile (as defined")" 1

  if ! has python3; then
    skip "installer over HTTP (partial download, wget)" "python3 missing"
    return
  fi
  port="$(python3 -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])')"
  python3 "$ROOT/tests/serve.py" "$ROOT" "$port" > /dev/null 2>&1 &
  srv=$!
  for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
    curl -sf "http://127.0.0.1:$port/aliases.sh" > /dev/null && break
    sleep 0.2
  done

  home="$TMP/i-partial" && mkdir -p "$home" && echo "# old install" > "$home/.git_aliases"
  inst "$home" "$curl_path" "http://127.0.0.1:$port/partial/aliases.sh" > /dev/null
  check "download cut short (curl): exit 1, old install kept, no temp file left" "$?:$(cat "$home/.git_aliases"):$(find "$home" -name '.git_aliases.*' | wc -l | tr -d ' ')" "1:# old install:0"

  if has wget; then
    local wget_path
    wget_path="$(fake_path wget wget)"
    home="$TMP/w-ok" && mkdir -p "$home" && touch "$home/.bashrc"
    inst "$home" "$wget_path" "http://127.0.0.1:$port/aliases.sh" > /dev/null
    check "install (wget): exit 0, installed" "$?:$([ -s "$home/.git_aliases" ] && echo yes)" "0:yes"
    home="$TMP/w-keep" && mkdir -p "$home" && echo "# old install" > "$home/.git_aliases"
    inst "$home" "$wget_path" "http://127.0.0.1:$port/nope.sh" > /dev/null
    check "failed update (wget 404): exit 1, old install kept" "$?:$(cat "$home/.git_aliases")" "1:# old install"
    home="$TMP/w space" && mkdir -p "$home" && touch "$home/.bashrc"
    inst "$home" "$wget_path" "http://127.0.0.1:$port/aliases.sh" > /dev/null
    check 'install (wget), $HOME with a space: installed' "$?:$([ -s "$home/.git_aliases" ] && echo yes)" "0:yes"
    # shellcheck disable=SC2016
    home="$TMP/w"'$(touch INJECTED)' && mkdir -p "$home" && touch "$home/.bashrc"
    inst "$home" "$wget_path" "http://127.0.0.1:$port/aliases.sh" > /dev/null
    check 'install (wget), $HOME with $(...): not executed, installed' "$?:$(find "$TMP" -name INJECTED | wc -l | tr -d ' '):$([ -s "$home/.git_aliases" ] && echo yes)" "0:0:yes"
  else
    skip "installer with wget" "wget missing"
  fi
  kill "$srv" 2> /dev/null
}

# --- main ----------------------------------------------------------------------------

echo "# aliases under $SHELL_NAME ($("${SHELL_CMD[0]}" --version 2>&1 | head -1)), $(git --version)"
for area in basics errors stash sync fixup editor lint pushf remote completion misc install; do
  case "$area" in
  *"$FILTER"*) ;;
  *) continue ;;
  esac
  echo "# $area"
  "t_$area"
  cd "$TMP" || exit 1
done
echo "# $pass passed, $fail failed, $skipped skipped"
[ "$fail" -eq 0 ]
