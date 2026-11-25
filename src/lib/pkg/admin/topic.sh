#!/bin/bash
#
# SPDX-License-Identifier: GPL-3.0-or-later

[[ -z ${ARTOOLS_INCLUDE_ADMIN_TOPIC_SH:-} ]] || return 0
ARTOOLS_INCLUDE_ADMIN_TOPIC_SH=1

set -e


artixpkg_admin_topic_usage() {
    local -r COMMAND=${_ARTOOLS_COMMAND:-${BASH_SOURCE[0]##*/}}
    cat <<- _EOF_
    Usage: ${COMMAND} [OPTIONS] [PKGBASE]...

    OPTIONS
        -a, --add NAME             Add a topic to repo
        -r, --remove NAME          Remove a topic from repo
        -d, --delete               Delete all topics from repo
        -j, --jobs N               Run up to N jobs in parallel (default: $(nproc))
        -h, --help                 Show this help text

    EXAMPLES
        $ ${COMMAND} --add mytopic libfoo
        $ ${COMMAND} --remove mytopic libbar
        $ ${COMMAND} --add mytopic libfoo libbar
        $ ${COMMAND} --remove mytopic libfoo libbar
        $ ${COMMAND} --delete libfoo
_EOF_
}



artixpkg_admin_topic() {
    if (( $# < 1 )); then
        artixpkg_admin_topic_usage
        exit 0
    fi

    # options
    local pkgbases=()
    local pkgbase

    local ADD_TOPIC
    local RM_TOPIC
    local ADD=0
    local RM=0
    local DEL=0
    local jobs=
    jobs=$(nproc)

    local RUNCMD=${_ARTOOLS_COMMAND:-${BASH_SOURCE[0]##*/}}

    while (( $# )); do
        case $1 in
            -h|--help)
                artixpkg_admin_topic_usage
                exit 0
            ;;
            -a|--add)
                (( $# <= 1 )) && die "missing argument for %s" "$1"
                ADD_TOPIC="$2"
                ADD=1
                RUNCMD+=" $1 ${ADD_TOPIC}"
                shift 2
            ;;
            -r|--remove)
                (( $# <= 1 )) && die "missing argument for %s" "$1"
                RM_TOPIC="$2"
                RM=1
                RUNCMD+=" $1 ${RM_TOPIC}"
                shift 2
            ;;
            -d|--delete)
                DEL=1
                RUNCMD+=" $1"
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
                break
            ;;
        esac
    done

    pkgbases+=("$@")

    if [[ -n ${GIT_TOKEN} ]]; then

        # parallelization
        if [[ ${jobs} != 1 ]] && (( ${#pkgbases[@]} > 1 )); then
            if [[ -n ${BOLD} ]]; then
                export ARTOOLS_COLOR=always
            fi
            if ! parallel --bar --jobs "${jobs}" "${RUNCMD}" ::: "${pkgbases[@]}"; then
                die 'Failed to manage some topic, please check the output'
                exit 1
            fi
            exit 0
        fi

        for pkgbase in "${pkgbases[@]}"; do
            local gitname
            gitname=$(get_compliant_name "${pkgbase}")

            # topics meta
            if (( ADD )); then
                if ! add_topic "${gitname}" "${ADD_TOPIC}"; then
                    warning "failed to add topic: ${ADD_TOPIC}"
                fi
            fi

            if (( RM )); then
                if ! remove_topic "${gitname}" "${RM_TOPIC}"; then
                    warning "failed to remove topic: ${RM_TOPIC}"
                fi
            fi

            if (( DEL )); then
                if ! remove_all_topics "${gitname}" "${GIT_ORG}"; then
                    warning "failed to delete all topics: ${gitname}"
                fi
            fi

        done

    fi
}
