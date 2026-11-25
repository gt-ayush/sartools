#!/bin/bash
#
# SPDX-License-Identifier: GPL-3.0-or-later

[[ -z ${ARTOOLS_INCLUDE_GIT_PUSH_SH:-} ]] || return 0
ARTOOLS_INCLUDE_GIT_PUSH_SH=1

set -e


artixpkg_git_push_usage() {
    local -r COMMAND=${_ARTOOLS_COMMAND:-${BASH_SOURCE[0]##*/}}
    cat <<- _EOF_
    Usage: ${COMMAND} [OPTIONS] [PKGBASE]...

    OPTIONS
        -m, --maintainer NAME      Push all packages of the named maintainer
        -t, --topic NAME           Push all packages of the named topic
        -h, --help                 Show this help text

    EXAMPLES
        $ ${COMMAND} libfoo linux libbar
        $ ${COMMAND} --maintainer tux
        $ ${COMMAND} --topic mytopic
_EOF_
}



artixpkg_git_push() {
    if (( $# < 1 )); then
        artixpkg_git_push_usage
        exit 0
    fi

    # options
    local MAINTAINER=
    local TOPIC=

    while (( $# )); do
        case $1 in
            -h|--help)
                artixpkg_git_push_usage
                exit 0
            ;;
            -m|--maintainer)
                (( $# <= 1 )) && die "missing argument for %s" "$1"
                MAINTAINER="$2"
                shift 2
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

                msg "Pushing ${pkgbase} ..."
                if ! git push origin master; then
                    die 'failed to push %s' "${pkgbase}"
                fi

            )
        else
            warning "Skipped pushing ${pkgbase}: Directory does not exist"
        fi
    done
}
