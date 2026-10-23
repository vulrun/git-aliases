# Git Aliases ![v2.0-beta](https://img.shields.io/static/v1?style=flat-square&label=version&message=v2.0-beta&color=blue)

## Table of Contents
- [About](#about)
- [Prerequisite](#prerequisite)
- [Installation](#installation)
- [Aliases](#aliases)
- [Examples](#examples)
- [Contributing](#contributing)
- [License](#license)

---

## About
git_aliases provide short-hands for [git](https://git-scm.com). Immensely are the functions written for saving the time of each developer. They are shell functions for **bash** and **zsh** (not plain `sh`/`dash`), on Linux, macOS, and Windows WSL.


## Prerequisite
- `git`, please be sure it is installed on the machine (2.30 or newer for `git-pushf`)
- `bash` or `zsh` as your shell
```sh
apt install git
```


## Installation
### Install & Update Script

To **install** or **update**, you should run the install script. To do that, you may either download and run the script manually or use the following cURL or wget command:
```sh
curl -o- https://raw.githubusercontent.com/vulrun/git-aliases/v2.0-beta/install.sh | bash
```
```sh
wget -qO- https://raw.githubusercontent.com/vulrun/git-aliases/v2.0-beta/install.sh | bash
```
Running either of the above commands downloads a script and runs it. The script downloads `aliases.sh` to `~/.git_aliases`, and attempts to add the source lines from the snippet below to the correct profile file (`~/.zshrc` for zsh users, otherwise `~/.bashrc`, `~/.bash_profile`, or `~/.profile`). If the download fails, an existing install and your profile are left untouched.

#### Additional Notes

- If the environment variable `$XDG_CONFIG_HOME` is present, it will place the `.git_aliases` file there.

- You can customize the install with these environment variables, placed right before `bash`:
  - `XYZ_PATH`: full path of the file to install (default `~/.git_aliases`); its directory must exist
  - `PROFILE`: the profile file to add the source line to (`/dev/null` leaves your profiles alone)
  - `XYZ_INSTALL_VERSION`: git tag or branch to install (default `v2.0-beta`)
  - `XYZ_INSTALL_GITHUB_REPO`: `owner/repo` to download from (default `vulrun/git-aliases`)
  - `XYZ_SOURCE`: full URL of `aliases.sh`, overriding the two above

  Eg: `curl -o- https://raw.githubusercontent.com/vulrun/git-aliases/v2.0-beta/install.sh | PROFILE="$HOME/.bashrc" bash`

- The installer can use, `curl`, or `wget` to download `.git_aliases`, whichever is available.

### Verify Installation
To verify that **git-aliases** has been installed, do:
```sh
git-aliases
```
which should output aliases version, if the installation was successful. Please note that `which git-aliases` will not work, since all are sourced shell functions, not executable binaries.

### Manual Install & Upgrade
For a fully manual install, execute the following lines to first clone the repository into `~/git-aliases`, copy the script out of it & then load it:
```sh
git clone https://github.com/vulrun/git-aliases.git "$HOME/git-aliases"
cp "$HOME/git-aliases/aliases.sh" "$HOME/.git_aliases"
source "$HOME/.git_aliases"
```
To upgrade later: `git -C "$HOME/git-aliases" pull && cp "$HOME/git-aliases/aliases.sh" "$HOME/.git_aliases"`
Now, add these lines to your `~/.bashrc`, `~/.profile`, or `~/.zshrc` file to have it automatically sourced upon login:
_(you may have to add to more than one of the above files)_
```sh
[ -s "$HOME/.git_aliases" ] && source "$HOME/.git_aliases"   # This loads git-aliases
```

### Manual Uninstall
To remove `aliases` manually, execute the following:
```sh
rm "$HOME/.git_aliases"
rm -rf "$HOME/git-aliases"   # only if you installed manually
```
Edit your profile-files `~/.bashrc`, `~/.profile`, or `~/.zshrc` (or other shell resource config) and remove the lines similar to :

```sh
[ -s "$HOME/.git_aliases" ] && source "$HOME/.git_aliases"   # This loads git-aliases
```
----------------------------
## Aliases
Arguments are written in square braces `[...]` are optional. `[**]` denotes, you can always use core options/commands from core `git`.
- `git-aliases` [goto 👇](#git-ver)
- `git-ver` [goto 👇](#git-ver)
- `git-ll` [goto 👇](#git-ll--git-log--git-logs)
- `git-log` [goto 👇](#git-ll--git-log--git-logs)
- `git-logs` [goto 👇](#git-ll--git-log--git-logs)
- `git-it "type(scope): message"` [goto 👇](#git-it)
- `git-up "type(scope): message" [origin [branch]] [**]` [goto 👇](#git-up)
- `git-amend ["type(scope): message"]` [goto 👇](#git-amend)
- `git-amend-now ["type(scope): message"]` [goto 👇](#git-amend-now)
- `git-push [origin [branch]] [**]` [goto 👇](#git-push--git-pushf)
- `git-pushf [origin [branch]] [**]` [goto 👇](#git-push--git-pushf)
- `git-pull [origin [branch]] [**]` [goto 👇](#git-pull)
- `git-pullf [origin [branch]]` [goto 👇](#git-pullf)
- `git-clean` [goto 👇](#git-clean)
- `git-clear` [goto 👇](#git-clear)
- `git-sync [origin [branch]]` [goto 👇](#git-sync)
- `git-fixit [commit]` [goto 👇](#git-fixit)
- `git-fixup [commit] [origin [branch]] [**]` [goto 👇](#git-fixup)
- `git-rebase [**]` [goto 👇](#git-rebase)
- `git-merge <branch>` [goto 👇](#git-merge)
- `git-merge-to <branch>` [goto 👇](#git-merge-to)
- `git-reset [commit_hash]` [goto 👇](#git-reset--git-resetf)
- `git-resetf [commit_hash]` [goto 👇](#git-reset--git-resetf)
- `git-stash` [goto 👇](#git-stash)
- `git-sstash` [goto 👇](#git-sstash)
- `git-nstash` [goto 👇](#git-nstash)


### git-ver
> Prints the **current version** of the git-aliases
```sh
git-ver
# v2.0-beta

git-aliases
# git-aliases is at v2.0-beta
```


### git-ll && git-log && git-logs
> Long List of **commit history**, each in single row with proper color for better readability _(latest to oldest order)_
```sh
git-ll
git-log
git-logs
# <commit-id> - <origin-branch> <commit-message> (<commit-time>) [<commit-author>]
```


### git-it
> add all files to staged list and **commit it**
```sh
git-it "feat(auth): add oauth login"
```
The message is checked first; if it doesn't follow the format below, nothing is staged or committed.

Please ensure your commit message follows the conventional commits format:
> `type(scope)!: description`

  - **type** could be one of: build, chore, ci, docs, feat, fix, perf, refactor, revert, style, test
  - **scope** is optional and can be anything specifying the place of the commit change
  - **!** is optional and marks a breaking change
  - **description** is a short description of the change


These conventions make it easier for others to understand the changes, streamline the development process, and help in generating changelogs or navigating through the history of the project.

- **build**: changes that affect the build system or external dependencies
- **chore**: regular code maintenance
- **ci**: changes made to CI configuration files and scripts
- **docs**: documentation related changes
- **feat**: a new feature added
- **fix**: a bug fix
- **perf**: changes that improves performance
- **refactor**: changes that neither fixes a bug nor adds a feature
- **revert**: if the commit reverts a previous commit, this is used with the hash of the commit being reverted
- **style**: changes that do not affect the meaning of the code (white-space, formatting, missing semi-colons, etc)
- **test**: changes that adds missing tests or corrects existing tests

### git-up
> Add all files to staged list and commit it. Finally, **push up** to the remote server. You may specify origin & branch at the end.
```sh
git-up "fix: handle empty input"

git-up "feat: new featured changes" origin beta
```


### git-amend
> **Modifying your last commit**. This will update uncommit changes to the last commit. If you are specifying the commit-message, then it will be updated too. Mostly used for correction purposes. In case of amendments, code must be pushed forcefully otherwise it will throw an error.
```sh
git-amend

git-amend "fix(api): return 404 for missing users"
```


### git-amend-now
> **Modifying your last commit**. This will update commit time, author who is working at the foremost. If you are specifying the commit-message, then it will be updated too. Mostly used for correction purposes. In case of amendments, code must be pushed forcefully otherwise it will throw an error.
```sh
git-amend-now

git-amend-now "docs: describe the new flags"
```


### git-push & git-pushf
> **Push all pending commits to remote cloud**. If pushed with `git-pushf`, commits are **forced** to be pushed, but it refuses to overwrite commits on the remote that you haven't pulled in yet (`--force-with-lease --force-if-includes`, git 2.30+); pull & integrate them, then push again.
```sh
git-push

# with origin
git-push new_origin

# with origin & branch
git-push new_origin slave

# you may also add core git push options at the end
git-push new_origin staging --tags

# NOTE: git-pushf options are same as in git-push
```
If the repository has more than one remote and you don't name one, you'll be asked to pick it with the arrow keys (or `j`/`k`) and Enter; the current branch's upstream remote (else `origin`) is highlighted first. `git-pull`, `git-pullf` and `git-sync` ask the same way.


### git-pull
> **Pull all pending commits from remote cloud**. This is launched with auto detection.
```sh
git-pull

# with origin
git-pull new_origin

# with origin & branch
git-pull new_origin slave

# you may also add core git pull options at the end
git-pull new_origin staging --rebase

```


### git-pullf
> **Pull changes** from remote cloud, and forcefully reset with your current branch (`git fetch --all` + `git reset --hard <origin>/<branch>`). **Uncommitted changes and local commits that aren't on the remote branch are discarded.**
```sh
git-pullf

# with origin
git-pullf new_origin

# with origin & branch
git-pullf new_origin staging

```


### git-clean
> **Clean garbage** from the `.git` directory: runs `git gc --prune=now --aggressive`, which compacts the repository and immediately deletes unreachable objects. It works locally and doesn't touch your working files (that's `git-clear`).
```sh
git-clean
```


### git-clear
> **Clear your working space**. This will discard all staged & unstaged changes and delete untracked files anywhere in the repository (`git reset --hard` + `git clean -df`); ignored files are kept. This cannot be undone.
```sh
git-clear
```


### git-sync
> **Sync from remote**. Stashes your local changes (including untracked files), switches to the branch, hard-resets it to the remote branch, prunes deleted remote branches, then brings your changes back. **Local commits that aren't on the remote branch are discarded.** If a step fails, your changes are still restored; if restoring them conflicts, they are kept in `stash@{0}`.
```sh
git-sync

# with origin
git-sync new_origin

# with origin & branch
git-sync new_origin staging
```


### git-fixit
> **Fixing previous commit**. This will add a new commit with **fixup** tag as prefix to the target commit message (the last commit by default). 
```sh
# same purpose as git-amend but here this will create a new commit
git-fixit

# fixing an older commit
git-fixit HEAD~2
git-fixit 84c63b39
```
Commit hooks are skipped (`--no-verify`) so commit-message linters don't reject the `fixup!` message.

### git-fixup
> **Fixing previous commit & push it**. This will add a fixup commit & push on remote origin. 
```sh
# same purpose as git-amend but here this will create a new commit
git-fixup

# with origin
git-fixup origin

# with origin & branch
git-fixup new_origin staging

# fixing an older commit, optionally with origin & branch
git-fixup HEAD~2
git-fixup 84c63b39 new_origin staging
```
If the first argument is the name of a remote, the last commit is fixed and pushed there; otherwise it is the commit to fix.


### git-rebase
> **Automatically Rebase Commits**. This will rebase your commits based on the prefix keywords added till the provided `HEAD`/`HASH`. 
```sh
# rebasing till hash
git-rebase 84c63b39
git-rebase 84c63b3910bb28b5f0549e235ac0f4f3a3c71a1b

# rebasing last 5 commits
git-rebase HEAD~5

# rebasing from root
git-rebase --root
```


### git-merge
> **Automatically Merge Branch**. This ensures that the merge is always done with a separate merge commit.
```sh
# merging new branches
git-merge feature-branch
git-merge another-feature-branch
```


### git-merge-to
> **Automatically Merge Branch**. This helps to merge the feature branch to main branch without changing the branch, you can continue working in the same feature branch.
```sh
# merging feature branch to
git-merge-to main-branch
git-merge-to another-main-branch
```
If the merge conflicts, you are left on the target branch to resolve it.


### git-reset & git-resetf
> **Remove Commit**. If reset with `git-resetf`, codes are **forced** to be updated.
```sh
# removes last commit from history only
git-reset

# removes commit upto this hash,
# but the code remains unchanged
git-reset 84c63b39
git-reset 84c63b3910bb28b5f0549e235ac0f4f3a3c71a1b

# removes last commit & codes
git-resetf

# removes upto commit hash & codes
git-resetf 84c63b39
git-resetf 84c63b3910bb28b5f0549e235ac0f4f3a3c71a1b
```


### git-stash
> Stash **all changes**, including untracked files.

This function stashes **all** your local changes (both staged and unstaged), including untracked files, safely.

```sh
git-stash
```


### git-sstash
> Stash **only staged files**, keeping unstaged changes left in the working directory.

Use this when you want to stash just the staged changes while leaving your unstaged changes untouched in the working directory. Untracked files stay too. If an unstaged edit sits on top of a staged edit in the same lines, nothing is stashed and you get an error instead.

Bring the changes back with `git stash pop --index`; git refuses while the same files have unstaged edits, so commit or stash those first.

```sh
git-sstash
```


### git-nstash
> Stash **only unstaged files**, keeping staged changes left in the working directory.

Use this when you want to stash just your unstaged changes, while keeping staged changes intact in your working directory. Untracked files are stashed too.

The stash is taken on top of a temporary commit of your staged changes, so `git stash show` lists only the unstaged changes, and `git stash pop` applies cleanly once you've committed the staged ones.

```sh
git-nstash
```


----------------------------


## Examples
#### Example 1
```sh
$ git-it "feat(auth): add oauth login"
# c1b8fd544 - feat(auth): add oauth login (1 minutes ago) [webcdn]

$ git-fixit
# 7056e6ef2 - fixup! feat(auth): add oauth login (1 minutes ago) [webcdn]
# c1b8fd544 - feat(auth): add oauth login (2 minutes ago) [webcdn]

$ git-fixit
# d4bc5b9fa - fixup! fixup! feat(auth): add oauth login (1 minutes ago) [webcdn]
# 7056e6ef2 - fixup! feat(auth): add oauth login (2 minutes ago) [webcdn]
# c1b8fd544 - feat(auth): add oauth login (2 minutes ago) [webcdn]


$ git-rebase HEAD~3
# e33621e8e - feat(auth): add oauth login (a few seconds ago) [webcdn]
```

----------------------------


## Contributing
Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

Please run `tests/run.sh` (and `tests/run.sh --shell zsh` if you have zsh) before opening a pull request, and add tests for new behaviour. CI runs them on Linux and macOS, together with `shellcheck`.


## License
[MIT](https://choosealicense.com/licenses/mit/)