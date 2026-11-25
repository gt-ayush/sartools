#!/hint/bash
#
# SPDX-License-Identifier: GPL-3.0-or-later

[[ -z ${ARTOOLS_INCLUDE_REPO_MOVE_SH:-} ]] || return 0
ARTOOLS_INCLUDE_REPO_MOVE_SH=1

set -e


artixpkg_repo_move_usage() {
    local -r COMMAND=${_ARTOOLS_COMMAND:-${BASH_SOURCE[0]##*/}}
    cat <<- _EOF_
    Usage: ${COMMAND} [OPTIONS] [SOURCE_REPO] [DEST_REPO] [PKGBASE]...

    OPTIONS
        -p, --push              Push pkgbase
        -a, --agent NAME        Set the CI agent
                                [default: auto]
                                possible values: ${AGENTS[@]}
        -h, --help              Show this help text

    EXAMPLES
        $ ${COMMAND} ${ARTIX_DB[4]} ${ARTIX_DB[5]} libfoo
        $ ${COMMAND} --push ${ARTIX_DB[4]} ${ARTIX_DB[5]} libfoo
        $ ${COMMAND} --push ${ARTIX_DB_MAP[1]} ${ARTIX_DB_MAP[2]} libfoo
_EOF_
}

artixpkg_repo_move() {
    if (( $# < 1 )); then
        artixpkg_repo_move_usage
        exit 0
    fi

    # options
    local pkgbases=()
    local pkgbase

    local PUSH=0
    local AUTO=0

    local DEST
    local SRC
    local AGENT

    while (( $# )); do
        case $1 in
            -h|--help)
                artixpkg_repo_move_usage
                exit 0
            ;;
            -p|--push)
                PUSH=1
                shift
            ;;
            -a|--agent)
                (( $# <= 1 )) && die "missing argument for %s" "$1"
                AGENT="$2"
                shift 2
            ;;
            -*)
                die "invalid argument: %s" "$1"
            ;;
            *)
                break
            ;;
        esac
    done

    SRC="$1"
    DEST="$2"
    shift 2

    if in_array "${SRC}" "${ARTIX_DB_MAP[@]}" && in_array "${DEST}" "${ARTIX_DB_MAP[@]}"; then
        AUTO=1
    else
        if ! in_array "${SRC}" "${ARTIX_DB[@]}"; then
            die "${SRC} does not exist!"
        fi
        if ! in_array "${DEST}" "${ARTIX_DB[@]}"; then
            die "${DEST} does not exist!"
        fi
    fi

    pkgbases+=("$@")

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

                    local team
                    team=$(detect_team)

                    if [[ -z "${team}" ]]; then
                        team=$(team_from_yaml)
                    fi

                    if (( AUTO )); then
                        if [[ "${SRC}" == "${ARTIX_DB_MAP[2]}" ]]; then
                            SRC="${team}"
                        else
                            SRC="${team}-${SRC}"
                        fi

                        if [[ "${DEST}" == "${ARTIX_DB_MAP[2]}" ]]; then
                            DEST="${team}"
                        else
                            DEST="${team}-${DEST}"
                        fi
                    fi

                    local commit_msg src_version
                    commit_msg=$(get_commit_msg 'move' "${DEST}" "${SRC}")

                    src_version=$(version_from_yaml "${SRC}")

                    if [[ "$src_version" != "null" ]]; then

                        if ! [[ -f "${SRCINFO}" ]]; then
                            pkg2yaml -o "${SRCINFO}"
                        fi

                        upgrade_db

                        update_yaml_move "${SRC}" "${DEST}"

                        team=$(detect_team)
                        if [[ -z "$team" ]]; then
                            team=$(team_from_yaml)
                        fi
                        update_yaml_team "${team}"

                        if [[ -z ${AGENT} ]]; then
                            AGENT=${AGENT_MAP["${team}"]}
                        fi
                        write_jenkinsfile "${AGENT}"

                        if [[ -f .SRCINFO ]]; then
                            rm .SRCINFO
                        fi

                        if [[ -n $(git status --porcelain --untracked-files=no) ]]; then

                            stat_busy 'Staging files'
                            for f in $(git ls-files --modified); do
                                if [[ "$f" == "${REPO_DB}" ]]; then
                                    git add "$f"
                                fi
                                if [[ "$f" == "${REPO_CI}" ]]; then
                                    git add "$f"
                                fi
                            done
                            for f in $(git ls-files --others); do
                                if [[ "$f" == "${SRCINFO}" ]]; then
                                    git add "$f"
                                fi
                            done
                            stat_done

                            msg 'Commit'
                            git commit -m "${commit_msg}"

                            if (( PUSH )); then
                                msg "Push (${pkgbase})"
                                git push origin master
                            fi

                            msg "Querying ${pkgbase} ..."
                            if ! show_db; then
                                warning "Could not query ${REPO_DB}"
                            fi

                        fi

                        if (( ! AUTO )); then

                            local gitname
                            gitname=$(get_compliant_name "${pkgbase}")

                            # team change on cross repo move system <-> world
                            if [[ "${SRC}" == ${ARTIX_DB[2]}* ]] \
                            && [[ "${DEST}" == ${ARTIX_DB[5]}* ]]; then
                                if ! add_team_to_repo "${gitname}" "${ARTIX_DB[5]}"; then
                                    warning "failed to add team: ${ARTIX_DB[5]}"
                                fi
                                if ! remove_team_from_repo "${gitname}" "${ARTIX_DB[2]}"; then
                                    warning "failed to remove team: ${ARTIX_DB[2]}"
                                fi
                            elif [[ "${SRC}" == ${ARTIX_DB[5]}* ]] \
                            && [[ "${DEST}" == ${ARTIX_DB[2]}* ]]; then
                                if ! add_team_to_repo "${gitname}" "${ARTIX_DB[2]}"; then
                                    warning "failed to add team: ${ARTIX_DB[2]}"
                                fi
                                if ! remove_team_from_repo "${gitname}" "${ARTIX_DB[5]}"; then
                                    warning "failed to remove team: ${ARTIX_DB[5]}"
                                fi
                            fi

                            # team change on cross repo move world <-> galaxy
                            if [[ "${SRC}" == ${ARTIX_DB[11]}* ]] \
                            && [[ "${DEST}" == ${ARTIX_DB[5]}* ]]; then
                                if ! add_team_to_repo "${gitname}" "${ARTIX_DB[5]}"; then
                                    warning "failed to add team: ${ARTIX_DB[5]}"
                                fi
                                if ! remove_team_from_repo "${gitname}" "${ARTIX_DB[11]}"; then
                                    warning "failed to remove team: ${ARTIX_DB[11]}"
                                fi
                            elif [[ "${SRC}" == ${ARTIX_DB[5]}* ]] \
                            && [[ "${DEST}" == ${ARTIX_DB[11]}* ]]; then
                                if ! add_team_to_repo "${gitname}" "${ARTIX_DB[11]}"; then
                                    warning "failed to add team: ${ARTIX_DB[11]}"
                                fi
                                if ! remove_team_from_repo "${gitname}" "${ARTIX_DB[5]}"; then
                                    warning "failed to remove team: ${ARTIX_DB[5]}"
                                fi
                            fi

                        fi

                    else
                        error "${pkgbase}: invalid move: version $src_version!"
                    fi

                fi

            )
        fi

    done
}
