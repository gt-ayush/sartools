#!/bin/bash
#
# SPDX-License-Identifier: GPL-3.0-or-later

[[ -z ${ARTOOLS_INCLUDE_GIT_CLONE_SH:-} ]] || return 0
ARTOOLS_INCLUDE_GIT_CLONE_SH=1

# shellcheck source=src/lib/pkg/git/config.sh
source "${LIBDIR}"/pkg/git/config.sh
# shellcheck source=src/lib/pkg/admin/team.sh
source "${LIBDIR}"/pkg/admin/team.sh

set -e


artixpkg_git_clone_usage() {
    local -r COMMAND=${_ARTOOLS_COMMAND:-${BASH_SOURCE[0]##*/}}
    cat <<- _EOF_
    Usage: ${COMMAND} [OPTIONS] [PKGBASE]...

    OPTIONS
        -m, --maintainer NAME      Clone all packages of the named maintainer
        -s, --search TOPIC         Clone all packages of the named topic
        -t, --team NAME            Assign team name (default: ${ARTIX_TEAMS[1]})
                                   Possible values: (${ARTIX_TEAMS[@]})
        -j, --jobs N               Run up to N jobs in parallel (default: $(nproc))
        --protocol https           Clone the repository over https
        --all                      Clone all existing packages, useful for cache warming
        -h, --help                 Show this help text

    EXAMPLES
        $ ${COMMAND} libfoo linux libbar
        $ ${COMMAND} --maintainer tux
        $ ${COMMAND} --search mytopic
        $ ${COMMAND} -j 8 --search mytopic
_EOF_
}



artixpkg_git_clone() {
    if (( $# < 1 )); then
        artixpkg_git_clone_usage
        exit 0
    fi

    # options
    local GIT_REPO_BASE_URL="${GIT_SSH}:"
    local CLONE_ALL=0
    local MAINTAINER=
    local TOPIC=
    local CONFIG_OPTS=()
    local TEAM_OPTS=()
    local jobs=
    jobs=$(nproc)

    local command=${_ARTOOLS_COMMAND:-${BASH_SOURCE[0]##*/}}

    while (( $# )); do
        case $1 in
            -h|--help)
                artixpkg_git_clone_usage
                exit 0
            ;;
            --protocol=https)
                GIT_REPO_BASE_URL="${GIT_HTTPS}/"
                CONFIG_OPTS+=("$1")
                shift
            ;;
            --protocol)
                (( $# <= 1 )) && die "missing argument for %s" "$1"
                if [[ $2 == https ]]; then
                    GIT_REPO_BASE_URL="${GIT_HTTPS}/"
                else
                    die "unsupported protocol: %s" "$2"
                fi
                CONFIG_OPTS+=("$1" "$2")
                shift 2
            ;;
            -m|--maintainer)
                (( $# <= 1 )) && die "missing argument for %s" "$1"
                MAINTAINER="$2"
                shift 2
            ;;
            -s|--search)
                (( $# <= 1 )) && die "missing argument for %s" "$1"
                TOPIC="$2"
                shift 2
            ;;
            -t|--team)
                (( $# <= 1 )) && die "missing argument for %s" "$1"
                TEAM_OPTS=("--add" "$2")
                shift 2
            ;;
            --all)
                CLONE_ALL=1
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
    if (( CLONE_ALL )); then
        mapfile -t pkgbases < <(list_all_repos | yq -P -r '.[] | .name' | sort)
    fi

    # parallelization
    if [[ ${jobs} != 1 ]] && (( ${#pkgbases[@]} > 1 )); then
        # force colors in parallel if parent process is colorized
        if [[ -n ${BOLD} ]]; then
            export ARTOOLS_COLOR=always
        fi
        if ! parallel --bar --jobs "${jobs}" "${command}" ::: "${pkgbases[@]}"; then
            die 'Failed to clone some packages, please check the output'
            exit 1
        fi
        exit 0
    fi

    for pkgbase in "${pkgbases[@]}"; do
        if [[ ! -d ${pkgbase} ]]; then
            msg "Cloning ${pkgbase} ..."
            local gitname url
            gitname=$(get_compliant_name "${pkgbase}")
            url="${GIT_REPO_BASE_URL}${GIT_ORG}/${gitname}.git"
            if ! git clone "${url}" "${pkgbase}"; then
                die 'failed to clone %s' "${pkgbase}"
            fi
        else
            warning "Skipped cloning ${pkgbase}: Directory exists"
        fi

        artixpkg_git_config "${CONFIG_OPTS[@]}" "${pkgbase}"
        artixpkg_admin_team "${TEAM_OPTS[@]}" "${pkgbase}"

    done
}
