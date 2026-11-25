#!/hint/bash
#
# SPDX-License-Identifier: GPL-3.0-or-later

[[ -z ${ARTOOLS_INCLUDE_REPO_SHOW_SH:-} ]] || return 0
ARTOOLS_INCLUDE_REPO_SHOW_SH=1

set -e


artixpkg_repo_show_usage() {
    local -r COMMAND=${_ARTOOLS_COMMAND:-${BASH_SOURCE[0]##*/}}
    cat <<- _EOF_
    Usage: ${COMMAND} [OPTIONS] [DEST_REPO] [PKGBASE]...

    OPTIONS
        -b, --base         Show srcinfo base
        -p, --pkgs         Show srcinfo pkgs
        -h, --help         Show this help text

    EXAMPLES
        $ ${COMMAND} libfoo
        $ ${COMMAND} -b libfoo
        $ ${COMMAND} -p libfoo
_EOF_
}

artixpkg_repo_show() {
    if (( $# < 1 )); then
        artixpkg_repo_show_usage
        exit 0
    fi

    # options
    local pkgbases=()
    local pkgbase
    local SRC_BASE=0
    local SRC_PKGS=0

    while (( $# )); do
        case $1 in
            -h|--help)
                artixpkg_repo_show_usage
                exit 0
            ;;
            -b|--base)
                SRC_BASE=1
                shift
            ;;
            -p|--pkgs)
                SRC_PKGS=1
                shift
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

    for pkgbase in "${pkgbases[@]}"; do

        if [[ -d "${pkgbase}" ]];then

            if [[ ! -d "${pkgbase}/.git" ]]; then
                error "Not a Git repository: ${pkgbase}"
                continue
            fi
            ( cd "${pkgbase}" || return

                if no_remote_changes; then
                    if [[ ! -f PKGBUILD ]]; then
                        die "No PKGBUILD found in (%s)" "${pkgbase}"
                    fi

                    msg "Querying ${pkgbase} ..."
                    if ! show_db; then
                        warning "Could not query ${REPO_DB}"
                    fi

                    if (( SRC_BASE )); then
                        if [[ -f "${SRCINFO}" ]]; then
                            msg "Showing srcinfo pkgbase ..."
                            yq '.pkgbase' "${SRCINFO}"
                        fi
                    fi

                    if (( SRC_PKGS )); then
                        if [[ -f "${SRCINFO}" ]]; then
                            msg "Showing srcinfo pkgname ..."
                            yq '.pkgname' "${SRCINFO}"
                        fi
                    fi
                fi

            )
        fi

    done
}
