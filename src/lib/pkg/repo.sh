#!/hint/bash
#
# SPDX-License-Identifier: GPL-3.0-or-later

[[ -z ${ARTOOLS_INCLUDE_REPO_SH:-} ]] || return 0
ARTOOLS_INCLUDE_REPO_SH=1

# shellcheck source=src/lib/pkg/db/db.sh
source "${LIBDIR}"/pkg/db/db.sh

# shellcheck source=src/lib/pkg/db/upgrade.sh
source "${LIBDIR}"/pkg/db/upgrade.sh

set -e


load_makepkg_config

no_remote_changes() {
    local status
    msg "Checking for remote changes ..."
    git fetch origin &>/dev/null
    status=$(git status -sb --porcelain)
    if [[ "$status" == *behind* ]]; then
        msg2 "changes: yes"
        error "Remote changes detected! Please pull (%s)" "${pkgbase}"
        return 1
    fi
    msg2 "changes: no"
    return 0
}

artixpkg_repo_usage() {
    local -r COMMAND=${_ARTOOLS_COMMAND:-${BASH_SOURCE[0]##*/}}
    cat <<- _EOF_
    Usage: ${COMMAND} [COMMAND] [OPTIONS]

    COMMANDS
        add            Add built pkgbase to repo
        move           Move built pkgbase between repos
        remove         Remove built pkgbase from repo
        import         Import latest tag from arch upstream
        show           Show the pkgbase's repo db

    OPTIONS
        -h, --help     Show this help text

    EXAMPLES
        $ ${COMMAND} add ${ARTIX_DB_MAP[2]} libfoo
        $ ${COMMAND} remove ${ARTIX_DB_MAP[2]} libfoo
        $ ${COMMAND} move ${ARTIX_DB_MAP[1]} ${ARTIX_DB_MAP[2]} libfoo
        $ ${COMMAND} add ${ARTIX_DB[4]} libfoo
        $ ${COMMAND} remove ${ARTIX_DB[4]} libfoo
        $ ${COMMAND} move ${ARTIX_DB[3]} ${ARTIX_DB[4]} libfoo
        $ ${COMMAND} import libfoo
        $ ${COMMAND} show libfoo
_EOF_
}

artixpkg_repo() {
    if (( $# < 1 )); then
        artixpkg_repo_usage
        exit 0
    fi

    # option checking
    while (( $# )); do
        case $1 in
        -h|--help)
                artixpkg_repo_usage
                exit 0
        ;;
        add)
                _ARTOOLS_COMMAND+=" $1"
                shift
                # shellcheck source=src/lib/pkg/repo/add.sh
                source "${LIBDIR}"/pkg/repo/add.sh
                artixpkg_repo_add "$@"
                exit 0
        ;;
        move)
                _ARTOOLS_COMMAND+=" $1"
                shift
                # shellcheck source=src/lib/pkg/repo/move.sh
                source "${LIBDIR}"/pkg/repo/move.sh
                artixpkg_repo_move "$@"
                exit 0
        ;;
        remove)
                _ARTOOLS_COMMAND+=" $1"
                shift
                # shellcheck source=src/lib/pkg/repo/remove.sh
                source "${LIBDIR}"/pkg/repo/remove.sh
                artixpkg_repo_remove "$@"
                exit 0
        ;;
        import)
                _ARTOOLS_COMMAND+=" $1"
                shift
                # shellcheck source=src/lib/pkg/repo/import.sh
                source "${LIBDIR}"/pkg/repo/import.sh
                artixpkg_repo_import "$@"
                exit 0
        ;;
        show)
                _ARTOOLS_COMMAND+=" $1"
                shift
                # shellcheck source=src/lib/pkg/repo/show.sh
                source "${LIBDIR}"/pkg/repo/show.sh
                artixpkg_repo_show "$@"
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
