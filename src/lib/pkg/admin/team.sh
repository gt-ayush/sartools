#!/bin/bash
#
# SPDX-License-Identifier: GPL-3.0-or-later

[[ -z ${ARTOOLS_INCLUDE_ADMIN_TEAM_SH:-} ]] || return 0
ARTOOLS_INCLUDE_ADMIN_TEAM_SH=1

set -e


artixpkg_admin_team_usage() {
    local -r COMMAND=${_ARTOOLS_COMMAND:-${BASH_SOURCE[0]##*/}}
    cat <<- _EOF_
    Usage: ${COMMAND} [OPTIONS] [PKGBASE]...

    OPTIONS
        -c, --check                 Check if team is assigned
        -l, --list                  List repo teams
        -a, --add NAME              Add team to repo
                                    Possible values: (${ARTIX_TEAMS[@]})
        -r, --remove NAME           Remove team from repo
                                    Possible values: (${ARTIX_TEAMS[@]})
        -h, --help                  Show this help text

    EXAMPLES
        $ ${COMMAND} --check libfoo
        $ ${COMMAND} --list libfoo
        $ ${COMMAND} --add ${ARTIX_TEAMS[1]} libfoo
        $ ${COMMAND} --remove ${ARTIX_TEAMS[3]} libfoo
_EOF_
}



artixpkg_admin_team() {
    if (( $# < 1 )); then
        artixpkg_admin_team_usage
        exit 0
    fi

    # options
    local CHECK=0
    local LIST=0
    local TEAM_ADD
    local TEAM_RM
    local pkgbases=()
    local pkgbase

    while (( $# )); do
        case $1 in
            -h|--help)
                artixpkg_admin_team_usage
                exit 0
            ;;
            -a|--add)
                (( $# <= 1 )) && die "missing argument for %s" "$1"
                TEAM_ADD="$2"
                shift 2
            ;;
            -r|--remove)
                (( $# <= 1 )) && die "missing argument for %s" "$1"
                TEAM_RM="$2"
                shift 2
            ;;
            -c|--check)
                CHECK=1
                shift
            ;;
            -l|--list)
                LIST=1
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

    if [[ -n ${GIT_TOKEN} ]]; then

        for pkgbase in "${pkgbases[@]}"; do

            if [[ -d "${pkgbase}" ]];then

                if [[ ! -d "${pkgbase}/.git" ]]; then
                    error "Not a Git repository: ${pkgbase}"
                    continue
                fi
                ( cd "${pkgbase}" || return

                    local gitname
                    gitname=$(get_compliant_name "${pkgbase}")

                    if (( CHECK )); then
                        local team
                        team=$(team_from_yaml)
                        res=$(check_repo_team  "${gitname}" "${team}" | yq -rP '.name')
                        if [[ "$res" == "null" ]]; then
                            error "[%s] does not have team (%s) assigned" "$pkgbase" "${team}"
                        else
                            msg "[%s] has team (%s) assigned" "$pkgbase" "${team}"
                        fi
                    fi

                    if (( LIST )); then
                        list_repo_teams "${gitname}" | yq -rP '.[] | .name'
                    fi

                    if [[ -n ${TEAM_ADD} ]]; then

                        if ! add_team_to_repo "${gitname}" "${TEAM_ADD}"; then
                            warning "failed to add team: ${TEAM_ADD}"
                        fi


                        if [[ "$(team_from_yaml)" != "${TEAM_ADD}" ]] \
                        || [[ "$(team_from_yaml)" == "null" ]]; then
                            update_yaml_team "${TEAM_ADD}"
                            git add "${REPO_DB}"
                            git commit -m "Set team ${TEAM_ADD}"
                        fi

                    fi

                    if [[ -n ${TEAM_RM} ]]; then

                        if ! remove_team_from_repo "${gitname}" "${TEAM_RM}"; then
                            warning "failed to add team: ${TEAM_RM}"
                        fi

                    fi

                    msg "Querying ${pkgbase} ..."
                    if ! show_db; then
                        warning "Could not query ${REPO_DB}"
                    fi

                )
            fi

        done

    fi

}
