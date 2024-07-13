#!/usr/bin/env bash

{ # this ensures the entire script is downloaded #

  xyz_has() {
    type "$1" >/dev/null 2>&1
  }

  xyz_echo() {
    command printf %s\\n "$*" 2>/dev/null
  }

  xyz_grep() {
    GREP_OPTIONS='' command grep "$@"
  }

  xyz_download() {
    if xyz_has "curl"; then
      curl --fail --compressed -q "$@"
    elif xyz_has "wget"; then
      # Emulate curl with wget
      ARGS=$(xyz_echo "$@" | command sed -e 's/--progress-bar /--progress=bar /' \
        -e 's/--compressed //' \
        -e 's/--fail //' \
        -e 's/-L //' \
        -e 's/-I /--server-response /' \
        -e 's/-s /-q /' \
        -e 's/-sS /-nv /' \
        -e 's/-o /-O /' \
        -e 's/-C - /-c /')
      # shellcheck disable=SC2086
      eval wget $ARGS
    fi
  }

  #
  # Detect profile file if not specified as environment variable
  # (eg: PROFILE=~/.myprofile)
  # The echo'ed path is guaranteed to be an existing file
  # Otherwise, an empty string is returned
  #

  xyz_profile_is_bash_or_zsh() {
    local TEST_PROFILE
    TEST_PROFILE="${1-}"

    case "${TEST_PROFILE-}" in
    *"/.bashrc" | *"/.bash_profile" | *"/.zshrc")
      return
      ;;
    *)
      return 1
      ;;
    esac
  }

  xyz_try_profile() {
    if [ -z "${1-}" ] || [ ! -f "${1}" ]; then
      return 1
    fi
    xyz_echo "${1}"
  }

  xyz_detect_profile() {
    if [ "${PROFILE-}" = '/dev/null' ]; then
      # the user has specifically requested NOT to have nvm touch their profile
      return
    fi

    if [ -n "${PROFILE}" ] && [ -f "${PROFILE}" ]; then
      xyz_echo "${PROFILE}"
      return
    fi

    local DETECTED_PROFILE
    DETECTED_PROFILE=''

    if [ -n "${BASH_VERSION-}" ]; then
      if [ -f "$HOME/.bashrc" ]; then
        DETECTED_PROFILE="$HOME/.bashrc"
      elif [ -f "$HOME/.bash_profile" ]; then
        DETECTED_PROFILE="$HOME/.bash_profile"
      fi
    elif [ -n "${ZSH_VERSION-}" ]; then
      DETECTED_PROFILE="$HOME/.zshrc"
    fi

    if [ -z "$DETECTED_PROFILE" ]; then
      for EACH_PROFILE in ".profile" ".bashrc" ".bash_profile" ".zshrc"; do
        if DETECTED_PROFILE="$(xyz_try_profile "${HOME}/${EACH_PROFILE}")"; then
          break
        fi
      done
    fi

    if [ -n "$DETECTED_PROFILE" ]; then
      xyz_echo "$DETECTED_PROFILE"
    fi
  }

  xyz_default_install_path() {
    [ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}" || printf %s "${XDG_CONFIG_HOME}"
  }

  xyz_install_path() {
    if [ -n "$XYZ_PATH" ]; then
      printf %s "${XYZ_PATH}"
    else
      xyz_default_install_path
    fi
  }

  xyz_latest_version() {
    xyz_echo "v1.1-beta"
  }

  xyz_file_name() {
    xyz_echo ".git_aliases"
  }

  xyz_source() {
    local XYZ_GITHUB_REPO
    XYZ_GITHUB_REPO="${XYZ_INSTALL_GITHUB_REPO:-webcdn/git-aliases}"

    local XYZ_VERSION
    XYZ_VERSION="${XYZ_INSTALL_VERSION:-$(xyz_latest_version)}"

    local XYZ_METHOD
    XYZ_METHOD="$1"

    local XYZ_SOURCE_URL
    XYZ_SOURCE_URL="$XYZ_SOURCE"

    if [ -z "$XYZ_SOURCE_URL" ]; then
      if [ "_$XYZ_METHOD" = "_script" ]; then
        XYZ_SOURCE_URL="https://raw.githubusercontent.com/${XYZ_GITHUB_REPO}/${XYZ_VERSION}/aliases.sh"
      else
        xyz_echo >&2 "Unexpected value \"$XYZ_METHOD\" for \$XYZ_METHOD"
        return 1
      fi
    fi
    xyz_echo "$XYZ_SOURCE_URL"
  }

  install_xyz_as_script() {
    local XYZ_REMOTE_SRC
    XYZ_REMOTE_SRC="$(xyz_source script)"

    # Downloading to $XYZ_FULL_PATH
    if [ -f "$XYZ_FULL_PATH" ]; then
      xyz_echo "=> Script exists at '$XYZ_FULL_PATH', trying to update"
    else
      xyz_echo "=> Downloading script to '$XYZ_FULL_PATH'"
    fi

    xyz_download -s "$XYZ_REMOTE_SRC" -o "$XYZ_FULL_PATH" || {
      xyz_echo >&2 "Failed to download '$XYZ_REMOTE_SRC'"
      return 1
    } &

    # wait for downloading to finish
    for job in $(jobs -p | command sort); do
      wait "$job" || return $?
    done

    # marking file as executable
    chmod a+x "$XYZ_FULL_PATH" || {
      xyz_echo >&2 "Failed to mark '$XYZ_FULL_PATH' as executable"
      return 3
    }
  }

  xyz_do_install() {
    local XYZ_FULL_PATH
    XYZ_FULL_PATH="${XYZ_PATH:-$(xyz_install_path)/$(xyz_file_name)}"

    # alert if directory exists with same name & exit
    if [ -z "${XYZ_FULL_PATH-}" ]; then
      xyz_echo >&2 "=> Unable to get the installation path."
      exit 1
    elif [ -d "${XYZ_FULL_PATH}" ]; then
      xyz_echo >&2 "=> \"${XYZ_FULL_PATH}\" is a directory. This shouldn't exists."
      exit 1
    fi

    # decide a method for installation
    if [ -z "${METHOD}" ]; then
      # Autodetect install method
      if xyz_has xyz_download; then
        install_xyz_as_script
      else
        xyz_echo >&2 'You need curl, or wget to add git_aliases'
        exit 1
      fi
    else
      xyz_echo >&2 "The environment variable \$METHOD is set to \"${METHOD}\", which is not recognized as a valid installation method."
      exit 1
    fi

    # local PROFILE_INSTALL_DIR
    # PROFILE_INSTALL_DIR="$(xyz_install_path | command sed "s:^$HOME:\$HOME:")"

    local XYZ_INCLUDE_STRING
    XYZ_INCLUDE_STRING="\\n# Load git-aliases\\n[ -s \"$XYZ_FULL_PATH\" ] && \\. \"$XYZ_FULL_PATH\"  # this loads git_aliases\\n"

    local XYZ_PROFILE
    XYZ_PROFILE="$(xyz_detect_profile)"

    # check & append xyz file to profile file, it will load with terminal
    BASH_OR_ZSH=false

    if [ -z "${XYZ_PROFILE-}" ]; then
      local TRIED_PROFILE
      if [ -n "${PROFILE}" ]; then
        TRIED_PROFILE="${XYZ_PROFILE} (as defined in \$PROFILE), "
      fi
      xyz_echo "=> Profile not found. Tried ${TRIED_PROFILE-}~/.bashrc, ~/.bash_profile, ~/.zshrc, and ~/.profile."
      xyz_echo "=> Create one of them and run this script again"
      xyz_echo "   OR"
      xyz_echo "=> Append the following lines to the correct file yourself:"
      command printf "${XYZ_INCLUDE_STRING}"
      xyz_echo
    else
      if xyz_profile_is_bash_or_zsh "${XYZ_PROFILE-}"; then
        BASH_OR_ZSH=true
      fi
      if ! command grep -qc "$XYZ_FULL_PATH" "$XYZ_PROFILE"; then
        xyz_echo "=> Appending source string to $XYZ_PROFILE"
        command printf "${XYZ_INCLUDE_STRING}" >>"$XYZ_PROFILE"
      else
        xyz_echo "=> source string already in ${XYZ_PROFILE}"
      fi
    fi

    # execute aliases
    # shellcheck source=/dev/null
    \. "$XYZ_FULL_PATH"

    # warning
    xyz_echo "=> Close and reopen your terminal to start using git_aliases or run the following to use it now:"
    command printf "${XYZ_INCLUDE_STRING}"
    if ${BASH_OR_ZSH}; then
      command printf "${COMPLETION_STR}"
    fi

    # unsetting variables
    xyz_reset
  }

  #
  # Unsets the various functions defined
  # during the execution of the install script
  #
  xyz_reset() {
    unset -f xyz_has xyz_echo xyz_grep xyz_download xyz_profile_is_bash_or_zsh \
      xyz_try_profile xyz_detect_profile xyz_default_install_path xyz_install_path \
      xyz_latest_version xyz_file_name xyz_source install_xyz_as_script xyz_do_install \
      xyz_reset
  }

  [ "_$XYZ_ENV" = "_testing" ] || xyz_do_install

} # this ensures the entire script is downloaded #
