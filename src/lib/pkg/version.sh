#!/hint/bash
#
# SPDX-License-Identifier: GPL-3.0-or-later

[[ -z ${ARTOOLS_INCLUDE_VERSION_SH:-} ]] || return 0
ARTOOLS_INCLUDE_VERSION_SH=1

LIBDIR=${LIBDIR:-@datadir@}

set -e


artixpkg_version_usage() {
    local -r COMMAND=${_ARTOOLS_COMMAND:-${BASH_SOURCE[0]##*/}}
    cat <<- _EOF_
    Usage: ${COMMAND} [COMMAND] [OPTIONS]

    Check and manage package versions against upstream.

    COMMANDS
        check      Compares local package versions against upstream
        setup      Automatically detect and setup a basic nvchecker config
        upgrade    Adjust the PKGBUILD to match the latest upstream version

    OPTIONS
        -h, --help    Show this help text

    EXAMPLES
        $ ${COMMAND} check libfoo linux libbar
        $ ${COMMAND} setup libfoo
_EOF_
}

artixpkg_version() {
    if (( $# < 1 )); then
        artixpkg_version_usage
        exit 0
    fi

    while (( $# )); do
        case $1 in
            -h|--help)
                artixpkg_version_usage
                exit 0
            ;;
            check)
                _ARTOOLS_COMMAND+=" $1"
                shift
                # shellcheck source=src/lib/pkg/version/check.sh
                source "${LIBDIR}"/pkg/version/check.sh
                artixpkg_version_check "$@"
                exit $?
            ;;
            upgrade)
                _ARTOOLS_COMMAND+=" $1"
                shift
                # shellcheck source=src/lib/pkg/version/upgrade.sh
                source "${LIBDIR}"/pkg/version/upgrade.sh
                artixpkg_version_upgrade "$@"
                exit $?
            ;;
            setup)
                _ARTOOLS_COMMAND+=" $1"
                shift
                # shellcheck source=src/lib/pkg/version/setup.sh
                source "${LIBDIR}"/pkg/version/setup.sh
                artixpkg_version_setup "$@"
                exit 0
            ;;
            *)
                die "invalid argument: %s" "$1"
            ;;
        esac
    done
}
