#!/hint/bash
#
# SPDX-License-Identifier: GPL-3.0-or-later

[[ -z ${ARTOOLS_INCLUDE_ADMIN_SH:-} ]] || return 0
ARTOOLS_INCLUDE_ADMIN_SH=1

# shellcheck source=src/lib/pkg/db/db.sh
source "${LIBDIR}"/pkg/db/db.sh


set -e

artixpkg_admin_usage() {
    local -r COMMAND=${_ARTOOLS_COMMAND:-${BASH_SOURCE[0]##*/}}
    cat <<- _EOF_
    Usage: ${COMMAND} [COMMAND] [OPTIONS]

    COMMANDS
        maintainer        Manage repo maintainer
        query             Query maintainers and topics
        team              Manage repo team
        topic             Manage topics
        transfer          Transfer obsolete repository to landfill

    OPTIONS
        -h, --help     Show this help text

    EXAMPLES
        $ ${COMMAND} transfer libfoo libbar
        $ ${COMMAND} query --topic mytopic
        $ ${COMMAND} topic --add mytopic libfoo
        $ ${COMMAND} team --add ${ARTIX_TEAMS[3]} libfoo
        $ ${COMMAND} maintainer --adopt libfoo libbar
_EOF_
}

artixpkg_admin() {
    if (( $# < 1 )); then
        artixpkg_admin_usage
        exit 0
    fi

    # option checking
    while (( $# )); do
        case $1 in
        -h|--help)
            artixpkg_admin_usage
            exit 0
        ;;

        query)
            _ARTOOLS_COMMAND+=" $1"
            shift
            # shellcheck source=src/lib/pkg/admin/query.sh
            source "${LIBDIR}"/pkg/admin/query.sh
            artixpkg_admin_query "$@"
            exit 0
        ;;
        team)
            _ARTOOLS_COMMAND+=" $1"
            shift
            # shellcheck source=src/lib/pkg/admin/team.sh
            source "${LIBDIR}"/pkg/admin/team.sh
            artixpkg_admin_team "$@"
            exit 0
        ;;
        topic)
            _ARTOOLS_COMMAND+=" $1"
            shift
            # shellcheck source=src/lib/pkg/admin/query.sh
            source "${LIBDIR}"/pkg/admin/topic.sh
            artixpkg_admin_topic "$@"
            exit 0
        ;;
        transfer)
            _ARTOOLS_COMMAND+=" $1"
            shift
            # shellcheck source=src/lib/pkg/admin/transfer.sh
            source "${LIBDIR}"/pkg/admin/transfer.sh
            artixpkg_admin_transfer "$@"
            exit 0
        ;;
        maintainer)
            _ARTOOLS_COMMAND+=" $1"
            shift
            # shellcheck source=src/lib/pkg/admin/maintainer.sh
            source "${LIBDIR}"/pkg/admin/maintainer.sh
            artixpkg_admin_maintainer "$@"
            exit 0
        ;;
        -*)
            die "invalid argument: %s" "$1"
        ;;
        *)
            die "invalid command: %s" "$1"
        ;;
        esac
    done
}
