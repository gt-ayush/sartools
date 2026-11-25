#!/bin/bash
#
# SPDX-License-Identifier: GPL-3.0-or-later

[[ -z ${ARTOOLS_INCLUDE_ADMIN_QUERY_SH:-} ]] || return 0
ARTOOLS_INCLUDE_ADMIN_QUERY_SH=1

set -e


artixpkg_admin_query_usage() {
    local -r COMMAND=${_ARTOOLS_COMMAND:-${BASH_SOURCE[0]##*/}}
    cat <<- _EOF_
    Usage: ${COMMAND} [OPTIONS] [PKGBASE]...

    OPTIONS
        -m, --maintainer NAME      Query for packages of the named maintainer
        -t, --topic NAME           Query for packages of the named topic
        -h, --help                 Show this help text

    EXAMPLES
        $ ${COMMAND} --maintainer tux
        $ ${COMMAND} --topic mytopic
_EOF_
}



artixpkg_admin_query() {
    if (( $# < 1 )); then
        artixpkg_admin_query_usage
        exit 0
    fi

    # options
    local MAINTAINER=
    local TOPIC=

    while (( $# )); do
        case $1 in
            -h|--help)
                artixpkg_admin_query_usage
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
                break
            ;;
        esac
    done

    # Query packages of a maintainer
    if [[ -n ${MAINTAINER} ]]; then
        local maint
        maint="maintainer-${MAINTAINER}"
        mapfile -t pkgbases < <(search_topic "${maint}" | yq -r '.data | .[].name' | sort)
        printf "%s\n" "${pkgbases[@]}"
    fi

    if [[ -n ${TOPIC} ]]; then
        mapfile -t pkgbases < <(search_topic "${TOPIC}" | yq -P -r '.data | .[].name' | sort)
        printf "%s\n" "${pkgbases[@]}"
    fi

}
