#!/bin/bash
#
# SPDX-License-Identifier: GPL-3.0-or-later

[[ -z ${ARTOOLS_INCLUDE_GIT_PULL_SH:-} ]] || return 0
ARTOOLS_INCLUDE_GIT_PULL_SH=1

set -e

# shellcheck source=src/lib/pkg/db/db.sh
source "${LIBDIR}"/pkg/db/db.sh


artixpkg_git_pull_usage() {
    local -r COMMAND=${_ARTOOLS_COMMAND:-${BASH_SOURCE[0]##*/}}
    cat <<- _EOF_
    Usage: ${COMMAND} [OPTIONS] [PKGBASE]...

    OPTIONS
        -m, --maintainer NAME      Pull all packages of the named maintainer
        -t, --topic NAME           Pull all packages of the named topic
        -j, --jobs N               Run up to N jobs in parallel (default: $(nproc))
        --all                      Pull all existing packages
        -h, --help                 Show this help text

    EXAMPLES
        $ ${COMMAND} libfoo linux libbar
        $ ${COMMAND} --maintainer tux
        $ ${COMMAND} --topic mytopic
        $ ${COMMAND} -j 8 --topic mytopic
_EOF_
}



artixpkg_git_pull() {
    if (( $# < 1 )); then
        artixpkg_git_pull_usage
        exit 0
    fi

    # options
    local PULL_ALL=0
    local MAINTAINER=
    local TOPIC=
    local CONFIGURE_OPTIONS=()
    local jobs=
    jobs=$(nproc)

    local command=${_ARTOOLS_COMMAND:-${BASH_SOURCE[0]##*/}}

    while (( $# )); do
        case $1 in
            -h|--help)
                artixpkg_git_pull_usage
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
            --all)
                PULL_ALL=1
                shift
            ;;
            -j|--jobs)
                (( $# <= 1 )) && die "missing argument for %s" "$1"
                jobs=$2
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

    # Query all released packages
    if (( PULL_ALL )); then
        mapfile -t pkgbases < <(list_all_repos | yq -P -r '.[] | .name' | sort)
    fi

    # parallelization
    if [[ ${jobs} != 1 ]] && (( ${#pkgbases[@]} > 1 )); then
        # force colors in parallel if parent process is colorized
        if [[ -n ${BOLD} ]]; then
            export ARTOOLS_COLOR=always
        fi
        if ! parallel --bar --jobs "${jobs}" "${command}" ::: "${pkgbases[@]}"; then
            die 'Failed to pull some packages, please check the output'
            exit 1
        fi
        exit 0
    fi

    for pkgbase in "${pkgbases[@]}"; do
        if [[ -d ${pkgbase} ]]; then
            ( cd "${pkgbase}" || return

                msg "Pulling ${pkgbase} ..."
                if ! git pull origin master; then
                    die 'failed to pull %s' "${pkgbase}"
                fi

                msg "Querying ${pkgbase} ..."
                if ! show_db; then
                    warning "Could not query ${REPO_DB}"
                fi

            )
        else
            warning "Skipped pulling ${pkgbase}: Directory does not exist"
        fi
    done
}
