#!/hint/bash
#
# SPDX-License-Identifier: GPL-3.0-or-later

[[ -z ${ARTOOLS_INCLUDE_GIT_SH:-} ]] || return 0
ARTOOLS_INCLUDE_GIT_SH=1

set -e

artixpkg_git_usage() {
    local -r COMMAND=${_ARTOOLS_COMMAND:-${BASH_SOURCE[0]##*/}}
    cat <<- _EOF_
    Usage: ${COMMAND} [COMMAND] [OPTIONS]

    COMMANDS
        clone          Clone a package repository
        commit         Commit to a package repository
        config         Configure a clone according to artix specs
        create         Create a new Gitea package repository
        pull           Pull a package repository
        push           Push a package repository

    OPTIONS
        -h, --help     Show this help text

    EXAMPLES
        $ ${COMMAND} clone libfoo linux libbar
        $ ${COMMAND} clone --maintainer tux
        $ ${COMMAND} clone --search mytopic
        $ ${COMMAND} commit libfoo
        $ ${COMMAND} config libfoo
        $ ${COMMAND} create -c libfoo
_EOF_
}

artixpkg_git() {
    if (( $# < 1 )); then
        artixpkg_git_usage
        exit 0
    fi

    # option checking
    while (( $# )); do
        case $1 in
        -h|--help)
            artixpkg_git_usage
            exit 0
        ;;
        clone)
            _ARTOOLS_COMMAND+=" $1"
            shift
            # shellcheck source=src/lib/pkg/git/clone.sh
            source "${LIBDIR}"/pkg/git/clone.sh
            artixpkg_git_clone "$@"
            exit 0
        ;;
        commit)
            _ARTOOLS_COMMAND+=" $1"
            shift
            # shellcheck source=src/lib/pkg/git/commit.sh
            source "${LIBDIR}"/pkg/git/commit.sh
            artixpkg_git_commit "$@"
            exit 0
        ;;
        config)
            _ARTOOLS_COMMAND+=" $1"
            shift
            # shellcheck source=src/lib/pkg/git/config.sh
            source "${LIBDIR}"/pkg/git/config.sh
            artixpkg_git_config "$@"
            exit 0
        ;;
        create)
            _ARTOOLS_COMMAND+=" $1"
            shift
            # shellcheck source=src/lib/pkg/git/create.sh
            source "${LIBDIR}"/pkg/git/create.sh
            artixpkg_git_create "$@"
            exit 0
        ;;
        pull)
            _ARTOOLS_COMMAND+=" $1"
            shift
            # shellcheck source=src/lib/pkg/git/pull.sh
            source "${LIBDIR}"/pkg/git/pull.sh
            artixpkg_git_pull "$@"
            exit 0
        ;;
        push)
            _ARTOOLS_COMMAND+=" $1"
            shift
            # shellcheck source=src/lib/pkg/git/push.sh
            source "${LIBDIR}"/pkg/git/push.sh
            artixpkg_git_push "$@"
            exit 0
        ;;
        -*)
            die "invalid argument: %s" "$1"
        ;;
        *)
            die "invalid command: %s" "$1"
        ;;
        esac
    done
}
