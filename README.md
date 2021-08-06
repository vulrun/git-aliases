# Git Aliases ![v0.0.1-beta](https://img.shields.io/static/v1?style=flat-square&label=version&message=v1.0-beta&color=blue)


## About
git_aliases provide short-hands for [git](https://git-scm.com). Immensely are the functions written for saving the time of each developer. `git` works on any POSIX-compliant shell (sh, dash, ksh, zsh, bash), in particular on these platforms: unix, macOS, and windows WSL.


## Prerequisite
Only works with `git`, please be sure it should be installed on the machine.
```sh
apt install git
```


## Installation
### Install & Update Script

To **install** or **update**, you should run the install script. To do that, you may either download and run the script manually or use the following cURL or wget command:
```sh
curl -o- https://raw.githubusercontent.com/webcdn/git-aliases/v1.0-beta/install.sh | bash
```
```sh
wget -qO- https://raw.githubusercontent.com/webcdn/git-aliases/v1.0-beta/install.sh | bash
```
Running either of the above commands downloads a script and runs it. The script downloads the script to `$HOME` generally at `~/`, and attempts to add the source lines from the snippet below to the correct profile file (`~/.bash_profile`, `~/.zshrc`, `~/.profile`, or `~/.bashrc`).

#### Additional Notes

- If the environment variable `$XDG_CONFIG_HOME` is present, it will place the `.git_aliases` file there.

- You can customize the install source, directory, profile, and version using the `XYZ_SOURCE`, `XYZ_DIR`, `PROFILE`, and `NODE_VERSION` variables.
Eg: `curl ... | NVM_DIR="path/to/git-aliases"`. Ensure that the `NVM_DIR` does not contain a trailing slash.

- The installer can use, `curl`, or `wget` to download `.git_aliases`, whichever is available.

### Verify Installation
To verify that **git-aliases** has been installed, do:
```sh
git-aliases
```
which should output aliases version, if the installation was successful. Please note that `which git-aliases` will not work, since all are sourced shell functions, not executable binaries.

### Manual Install & Upgrade
For a fully manual install, execute the following lines to first clone repository into `$HOME`, and moving file out of the directory & then load it:
```sh
git clone https://github.com/webcdn/git-aliases.git "$HOME"
cd "$HOME"
mv ./git-aliases/aliases.sh ./.git_aliases
source ./.git_aliases
```
Now, add these lines to your `~/.bashrc`, `~/.profile`, or `~/.zshrc` file to have it automatically sourced upon login:
_(you may have to add to more than one of the above files)_
```sh
[ -s "$HOME/.git_aliases" ] && source "$HOME/.git_aliases"   # This loads git-aliases
```

### Manual Uninstall
To remove `aliases` manually, execute the following:
```sh
rm "$HOME/.git_aliases"
```
Edit your profile-files `~/.bashrc`, `~/.profile`, or `~/.zshrc` (or other shell resource config) and remove the lines similar to :

```sh
[ -s "$HOME/.git_aliases" ] && source "$HOME/.git_aliases"   # This loads git-aliases
```
----------------------------
## Aliases
Arguments are written in square braces `[...]` are optional. `[**]` denotes, you can always use core options/commands from core `git`.
- `git-ver`
- `git-ll`
- `git-it "your commit message"`
- `git-up ["your commit message" [origin [branch]]] [**]`
- `git-amend ["your commit message"]`
- `git-push [origin [branch]] [**]`
- `git-pushf [origin [branch]] [**]`
- `git-pull [origin [branch]] [**]`
- `git-pullf [origin [branch]]`
- `git-clean [reflogs]`
- `git-clear`
- `git-sync [origin [branch]]`
- `git-fixit`
- `git-fixup [origin [branch]] [**]`
- `git-rebase [**]`



### git-ver
> Prints the **current version** of the git-aliases
```sh
git-ver
# v1.0-beta
```


### git-ll
> Long List of **commit history**, each in single row with proper color for better readability _(latest to oldest order)_
```sh
git-ll
# <comit-id> - <origin-branch> <commit-message> (<commit-time>) [<commit-author>]
```


### git-it
> add all files to staged list and **commit it**
```sh
git-it "your commit message"
```


### git-up
> Add all files to staged list and commit it. Finally, **push up** to the remote server. You may specify origin & branch at the end.
```sh
git-up "your commit message"

git-up "new featured changes" origin beta
```


### git-amend
> **Modifying your last commit**. This will update commit time, author who is working at the foremost. If you are specifying the commit-message, then it will be updated too. Mostly used for correction purposes. In case of amendments, code must be pushed forcefully otherwise it will throw an error.
```sh
git-amend

git-amend "your commit message"
```


### git-push & git-pushf
> **Push all pending commits to remote cloud**. If pushed with `git-pushf`, commits are **forced** to be pushed.
```sh
git-push

# with origin
git-push new_origin

# with origin & branch
git-push new_origin slave

# you may also add core git push options at the end
git-push new_origin staging 

# NOTE: git-pushf options are same as in git-push
```


### git-pull
> **Pull all pending commits from remote cloud**. This is launched with auto detection.
```sh
git-pull

# with origin
git-pull new_origin

# with origin & branch
git-pull new_origin slave

# you may also add core git pull options at the end
git-pull new_origin staging 

```


### git-pullf
> **Pull changes** from remote cloud, and forcefully reset with your current branch.
```sh
git-pullf

# with origin
git-pullf new_origin

# with origin & branch
git-pullf new_origin staging

```


### git-clean
> **Clean garbage** or unnecessary reflog objects from the `.git` directory. It works locally.
```sh
git-clean
```


### git-clear
> **Clear your working space**. This will remove all staged & unstaged files.
```sh
git-clear
```


### git-sync
> **Sync from remote**. This additionally clear all the staged files & then pull the code forcefully
```sh
git-sync

# with origin
git-sync new_origin

# with origin & branch
git-sync new_origin staging
```


### git-fixit
> **Fixing previous commit**. This will add a new commit with **fixup** tag as prefix to previous commit message. 
```sh
# same purpose as git-amend but here this will create a new commit
git-fixit
```

### git-fixup
> **Fixing previous commit & push it**. This will add a fixup commit & push on remote origin. 
```sh
# same purpose as git-amend but here this will create a new commit
git-fixup

# with origin
git-fixup origin

# with origin & branch
git-fixup new_origin staging
```


### git-rebase
> **Automatically Rebase Commits**. This will rebase you commits based on the prefix keywords added till the provided `HEAD`/`HASH`. 
```sh
# rebasing till hash
git-rebase 84c63b39
git-rebase 84c63b3910bb28b5f0549e235ac0f4f3a3c71a1b

# rebasing last 5 commits
git-rebase HEAD~5

# rebasing from root
git-rebase --root
```


## Examples
#### Example 1
```sh
$ git-it
# c1b8fd544 - oauth added (1 minutes ago) [webcdn]

$ git-fixit
# 7056e6ef2 - fixup! oauth added (1 minutes ago) [webcdn]
# c1b8fd544 - oauth added (2 minutes ago) [webcdn]

$ git-fixit
# d4bc5b9fa - fixup! fixup! oauth added (1 minutes ago) [webcdn]
# 7056e6ef2 - fixup! oauth added (2 minutes ago) [webcdn]
# c1b8fd544 - oauth added (2 minutes ago) [webcdn]


$ git-rebase HEAD~3
# e33621e8e - oauth added (a few seconds ago) [webcdn]
```
----------------------------


## Contributing
Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

Please make sure to update tests as appropriate.


## License
[MIT](https://choosealicense.com/licenses/mit/)