#!/hint/bash
#
# SPDX-License-Identifier: GPL-3.0-or-later

[[ -z ${ARTOOLS_INCLUDE_REPO_REMOVE_SH:-} ]] || return 0
ARTOOLS_INCLUDE_REPO_REMOVE_SH=1

set -e


artixpkg_repo_remove_usage() {
    local -r COMMAND=${_ARTOOLS_COMMAND:-${BASH_SOURCE[0]##*/}}
    cat <<- _EOF_
    Usage: ${COMMAND} [OPTIONS] [DEST_REPO] [PKGBASE]...

    OPTIONS
        -p, --push              Push pkgbase
        -a, --agent NAME        Set the CI agent
                                [default: auto]
                                possible values: ${AGENTS[@]}
        -h, --help              Show this help text

    EXAMPLES
        $ ${COMMAND} ${ARTIX_DB[4]} libfoo
        $ ${COMMAND} --push ${ARTIX_DB[4]} libfoo
        $ ${COMMAND} --push ${ARTIX_DB_MAP[2]} libfoo
_EOF_
}

artixpkg_repo_remove() {
    if (( $# < 1 )); then
        artixpkg_repo_remove_usage
        exit 0
    fi

    # options
    local pkgbases=()
    local pkgbase

    local PUSH=0
    local AUTO=0
    local DEST=''
    local AGENT

    while (( $# )); do
        case $1 in
            -h|--help)
                artixpkg_repo_remove_usage
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

    DEST="$1"
    shift
    pkgbases=("$@")

    if in_array "${DEST}" "${ARTIX_DB_MAP[@]}"; then
        AUTO=1
    else
        if ! in_array "${DEST}" "${ARTIX_DB[@]}"; then
            die "${DEST} does not exist!"
        fi
    fi

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
                        if [[ "${DEST}" == "${ARTIX_DB_MAP[2]}" ]]; then
                            DEST="${team}"
                        else
                            DEST="${team}-${DEST}"
                        fi
                    fi

                    local commit_msg
                    commit_msg=$(get_commit_msg 'remove' "${DEST}")

                    if ! [[ -f "${SRCINFO}" ]]; then
                        pkg2yaml -o "${SRCINFO}"
                    fi

                    upgrade_db

                    update_yaml_remove "${DEST}"

                    if [[ -z ${AGENT} ]]; then
                        AGENT=${AGENT_MAP["${team}"]}
                    fi
                    write_jenkinsfile "${AGENT}"

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

                fi
            )
        fi

    done
}
