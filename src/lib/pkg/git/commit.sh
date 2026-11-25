#!/bin/bash
#
# SPDX-License-Identifier: GPL-3.0-or-later

[[ -z ${ARTOOLS_INCLUDE_GIT_COMMIT_SH:-} ]] || return 0
ARTOOLS_INCLUDE_GIT_COMMIT_SH=1

# shellcheck source=src/lib/pkg/db/db.sh
source "${LIBDIR}"/pkg/db/db.sh

set -e


artixpkg_git_commit_usage() {
    local -r COMMAND=${_ARTOOLS_COMMAND:-${BASH_SOURCE[0]##*/}}
    cat <<- _EOF_
    Usage: ${COMMAND} [OPTIONS] [PKGBASE]...

    OPTIONS
        -c, --custom-message       Specify custom commit message instead of the default
        -m, --maintainer NAME      Commit all packages of the named maintainer
        -n, --no-staging           Disable automatic adding/removing of files to staging
        -p, --preserve-pkgbase     Do not automatically edit pkgbase.yaml to disable building
        -t, --topic NAME           Commit all packages of the named topic
        -h, --help                 Show this help text

    EXAMPLES
        $ ${COMMAND} libfoo linux libbar
        $ ${COMMAND} --maintainer tux
        $ ${COMMAND} --topic mytopic
_EOF_
}



artixpkg_git_commit() {
    if (( $# < 1 )); then
        artixpkg_git_commit_usage
        exit 0
    fi

    # options
    local MESSAGE=
    local MAINTAINER=
    local PKGBASE=1
    local STAGE=1
    local TOPIC=

    while (( $# )); do
        case $1 in
            -h|--help)
                artixpkg_git_commit_usage
                exit 0
            ;;
            -c|--custom-message)
                (( $# <= 1 )) && die "missing argument for %s" "$1"
                MESSAGE="$2"
                shift 2
            ;;
            -m|--maintainer)
                (( $# <= 1 )) && die "missing argument for %s" "$1"
                MAINTAINER="$2"
                shift 2
            ;;
            -n|--no-staging)
                STAGE=0
                shift
            ;;
            -p|--preserve-pkgbase)
                PKGBASE=0
                shift
            ;;
            -t|--topic)
                (( $# <= 1 )) && die "missing argument for %s" "$1"
                TOPIC="$2"
                shift 2
            ;;
            --)
                shift
                break
            ;;
            -*)
                die "invalid argument: %s" "$1"
            ;;
            *)
                pkgbases=("$@")
                break
            ;;
        esac
    done

    # Query packages of a maintainer
    if [[ -n ${MAINTAINER} ]]; then
        local maint
        maint="maintainer-${MAINTAINER}"
        mapfile -t pkgbases < <(search_topic "${maint}" | yq -P -r '.data | .[].name' | sort)
    fi

    if [[ -n ${TOPIC} ]]; then
        mapfile -t pkgbases < <(search_topic "${TOPIC}" | yq -P -r '.data | .[].name' | sort)
    fi

    for pkgbase in "${pkgbases[@]}"; do
        if [[ -d ${pkgbase} ]]; then
            ( cd "${pkgbase}" || return

                if (( PKGBASE )); then
                    update_yaml_commit ${pkgbase}
                fi

                if (( STAGE )); then
                    stat_busy 'Staging files'
                    ( git ls-files -z --others --exclude-standard
                        git ls-files -z --modified ) | xargs -r0 -- git add --
                    git ls-files -z --deleted | xargs -r0 -- git rm --
                    stat_done
                fi

                local commit_msg
                if [[ -n ${MESSAGE} ]]; then
                    commit_msg=${MESSAGE}
                else
                    commit_msg=$(get_commit_msg 'update')
                fi

                msg "Committing ${pkgbase} ..."
                git commit -m "${commit_msg}"
            )
        else
            warning "Skipped committing ${pkgbase}: Directory does not exist"
        fi
    done
}
