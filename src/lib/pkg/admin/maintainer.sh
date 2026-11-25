#!/bin/bash
#
# SPDX-License-Identifier: GPL-3.0-or-later

[[ -z ${ARTOOLS_INCLUDE_ADMIN_MAINTAINER_SH:-} ]] || return 0
ARTOOLS_INCLUDE_ADMIN_MAINTAINER_SH=1


set -e


artixpkg_admin_maintainer_usage() {
    local -r COMMAND=${_ARTOOLS_COMMAND:-${BASH_SOURCE[0]##*/}}
    cat <<- _EOF_
    Usage: ${COMMAND} [OPTIONS] [PKGBASE]...

    OPTIONS
        -a, --adopt            Adopt repo
        -o, --orphan           Orphan repo
        -h, --help             Show this help text

    EXAMPLES
        $ ${COMMAND} --adopt libfoo
        $ ${COMMAND} --orphan libfoo libbar
_EOF_
}



artixpkg_admin_maintainer() {
    if (( $# < 1 )); then
        artixpkg_admin_maintainer_usage
        exit 0
    fi

    # options
    local pkgbases=()
    local pkgbase

    local ADOPT=0
    local ORPHAN=0

    local packager_name
    local maintainer

    local RUNCMD=${_ARTOOLS_COMMAND:-${BASH_SOURCE[0]##*/}}

    while (( $# )); do
        case $1 in
            -h|--help)
                artixpkg_admin_maintainer_usage
                exit 0
            ;;
            -a|--adopt)
                ADOPT=1
                RUNCMD+=" $1"
                shift
            ;;
            -o|--orphan)
                ORPHAN=1
                RUNCMD+=" $1"
                shift
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

    # shellcheck source=src/lib/pkg/util/packager.sh
    source "${LIBDIR}"/pkg/util/packager.sh

    # shellcheck source=config/makepkg/x86_64.conf
    makepkg_load_config

    if [[ -n ${PACKAGER} ]]; then
        if ! packager_name=$(get_packager_name "${PACKAGER}") || \
            ! packager_email=$(get_packager_email "${PACKAGER}"); then
            die "invalid PACKAGER format '${PACKAGER}' in makepkg.conf"
        fi
        if ! is_packager_name_valid "${packager_name}"; then
            die "invalid PACKAGER '${PACKAGER}' in makepkg.conf"
        fi
        if is_packager_email_official "${packager_email}"; then
            maintainer="maintainer-${packager_name}"
        fi
    fi


    if [[ -n ${GIT_TOKEN} ]]; then

        # parallelization
        if [[ ${jobs} != 1 ]] && (( ${#pkgbases[@]} > 1 )); then
            # force colors in parallel if parent process is colorized
            if [[ -n ${BOLD} ]]; then
                export ARTOOLS_COLOR=always
            fi
            if ! parallel --bar --jobs "${jobs}" "${RUNCMD}" ::: "${pkgbases[@]}"; then
                die 'Failed to manange some packages, please check the output'
                exit 1
            fi
            exit 0
        fi

        for pkgbase in "${pkgbases[@]}"; do
            local gitname
            gitname=$(get_compliant_name "${pkgbase}")

            if (( ADOPT )); then
                if ! add_topic "${gitname}" "$maintainer"; then
                    warning "failed to add topic: $maintainer"
                fi
            fi

            if (( ORPHAN )); then
                if ! remove_topic "${gitname}" "$maintainer"; then
                    warning "failed to remove topic: $maintainer"
                fi
            fi

        done

    fi
}
