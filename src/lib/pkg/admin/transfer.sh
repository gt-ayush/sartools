#!/bin/bash
#
# SPDX-License-Identifier: GPL-3.0-or-later

[[ -z ${ARTOOLS_INCLUDE_ADMIN_TRANSFER_SH:-} ]] || return 0
ARTOOLS_INCLUDE_ADMIN_TRANSFER_SH=1

set -e


artixpkg_admin_transfer_usage() {
    local -r COMMAND=${_ARTOOLS_COMMAND:-${BASH_SOURCE[0]##*/}}
    cat <<- _EOF_
    Usage: ${COMMAND} [OPTIONS] [PKGBASE]...

    OPTIONS
        -h, --help             Show this help text

    EXAMPLES
        $ ${COMMAND} libfoo
        $ ${COMMAND} libfoo libbar
_EOF_
}



artixpkg_admin_transfer() {
    if (( $# < 1 )); then
        artixpkg_admin_transfer_usage
        exit 0
    fi

    # options
    local pkgbases=()
    local pkgbase

    local command=${_ARTOOLS_COMMAND:-${BASH_SOURCE[0]##*/}}

    while (( $# )); do
        case $1 in
            -h|--help)
                artixpkg_admin_transfer_usage
                exit 0
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
        for pkgbase in "${pkgbases[@]}"; do
            local gitname
            gitname=$(get_compliant_name "${pkgbase}")

            transfer_repo "${gitname}" "${GIT_ORG_ARCHIVE}"
            remove_all_topics "${gitname}" "${GIT_ORG_ARCHIVE}"
            archive_repo "${gitname}" "${GIT_ORG_ARCHIVE}"
        done
    fi
}
