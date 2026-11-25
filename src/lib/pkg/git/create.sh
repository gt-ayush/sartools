#!/bin/bash
#
# SPDX-License-Identifier: GPL-3.0-or-later

[[ -z ${ARTOOLS_INCLUDE_GIT_CREATE_SH:-} ]] || return 0
ARTOOLS_INCLUDE_GIT_CREATE_SH=1

# shellcheck source=src/lib/pkg/git/clone.sh
source "${LIBDIR}"/pkg/git/clone.sh
# shellcheck source=src/lib/pkg/git/config.sh
source "${LIBDIR}"/pkg/git/config.sh
# shellcheck source=src/lib/pkg/admin/team.sh
source "${LIBDIR}"/pkg/admin/team.sh

set -e


artixpkg_git_create_usage() {
    local -r COMMAND=${_ARTOOLS_COMMAND:-${BASH_SOURCE[0]##*/}}
    cat <<- _EOF_
    Usage: ${COMMAND} [OPTIONS] [PKGBASE]...

    OPTIONS
        -c, --clone           Clone the Git repository after creation
        -t, --team NAME       Assign team name (default: ${ARTIX_TEAMS[1]})
                              Possible values: (${ARTIX_TEAMS[@]})
        -h, --help            Show this help text

    EXAMPLES
        $ ${COMMAND} libfoo
_EOF_
}

artixpkg_git_create() {
    # options
    local pkgbases=()
    local pkgbase
    local CLONE=0
    local CONFIG=0

    local TEAM_OPTS=("--team" "${ARTIX_TEAMS[1]}")

    # variables
    local path

    while (( $# )); do
        case $1 in
        -h|--help)
            artixpkg_git_create_usage
            exit 0
        ;;
        -c|--clone)
            CLONE=1
            shift
        ;;
        -t|--team)
            (( $# <= 1 )) && die "missing argument for %s" "$1"
            TEAM_OPTS=("$1" "$2")
            shift 2
        ;;
        -*)
            die "invalid argument: %s" "$1"
        ;;
        *)
            break
        ;;
        esac
    done

    pkgbases=("$@")

    if ! in_array "${TEAM_OPTS[1]}" "${ARTIX_TEAMS[@]}"; then
        die "${TEAM} does not exist!"
    fi

    # check if invoked without any path from within a packaging repo
    if (( ${#pkgbases[@]} == 0 )); then
        if [[ -f PKGBUILD ]]; then
            if ! path=$(realpath -e .); then
                die "failed to read path from current directory"
            fi
            pkgbases=("$(basename "${path}")")
            CLONE=0
            CONFIG=1
        else
            artixpkg_git_create_usage
            exit 1
        fi
    fi

    # create
    for pkgbase in "${pkgbases[@]}"; do

        local gitname
        gitname=$(get_compliant_name "${pkgbase}")

        if [[ -n ${GIT_TOKEN} ]]; then
            if ! create_repo "${gitname}" >/dev/null; then
                die "failed to create repository: ${pkgbase}"
            else
                msg_success "Successfully created ${pkgbase}"
            fi
        fi

        if (( CLONE )); then
            artixpkg_git_clone "${TEAM_OPTS[@]}" "${pkgbase}"
        elif (( CONFIG )); then
            artixpkg_git_config "${pkgbase}"
            artixpkg_admin_team "${TEAM_OPTS[@]}" "${pkgbase}"
        fi

    done

    # some convenience hints if not in auto clone/config mode
    if (( ! CLONE )) && (( ! CONFIG )); then
        cat <<- _EOF_

        For new clones:
        $(msg2 "artixpkg git clone ${pkgbases[*]}")
        For existing clones:
        $(msg2 "artixpkg git config ${pkgbases[*]}")
_EOF_
    fi
}
