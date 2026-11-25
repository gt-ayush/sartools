#!/hint/bash
#
# SPDX-License-Identifier: GPL-3.0-or-later

[[ -z ${ARTOOLS_INCLUDE_REPO_ADD_SH:-} ]] || return 0
ARTOOLS_INCLUDE_REPO_ADD_SH=1

set -e


check_pkgbuild_validity() {
    # skip when there are no sources available
    if (( ! ${#source[@]} )); then
        return
    fi

    # validate sources hash algo is at least > sha1
    local bad_algos=("cksums" "md5sums" "sha1sums")
    local good_hash_algo=false

    # from makepkg libmakepkg/util/schema.sh
    for integ in "${known_hash_algos[@]}"; do
        local sumname="${integ}sums"
        if [[ -n ${!sumname} ]] && ! in_array "${sumname}" "${bad_algos[@]}"; then
            good_hash_algo=true
            break
        fi
    done

    if ! $good_hash_algo; then
        die "PKGBUILD lacks a secure cryptographic checksum, insecure algorithms: ${bad_algos[*]}"
    fi
}

artixpkg_repo_add_usage() {
    local -r COMMAND=${_ARTOOLS_COMMAND:-${BASH_SOURCE[0]##*/}}
    cat <<- _EOF_
    Usage: ${COMMAND} [OPTIONS] [DEST_REPO] [PKGBASE]...

    OPTIONS
        -p, --push              Push pkgbase
        -r, --rebuild           Triggers a rebuild
        -n, --nocheck           Disable the check function
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

artixpkg_repo_add() {
    if (( $# < 1 )); then
        artixpkg_repo_add_usage
        exit 0
    fi

    # options
    local pkgbases=()
    local pkgbase

    local PUSH=0
    local DEST=''
    local REBUILD=0
    local NOCHECK=0
    local ADD=1
    local AUTO=0
    local AGENT

    while (( $# )); do
        case $1 in
            -h|--help)
                artixpkg_repo_add_usage
                exit 0
            ;;
            -p|--push)
                PUSH=1
                shift
            ;;
            -r|--rebuild)
                REBUILD=1
                shift
            ;;
            -n|--nocheck)
                NOCHECK=1
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
    pkgbases+=("$@")

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

                    # shellcheck source=contrib/makepkg/PKGBUILD.proto
                    source PKGBUILD

                    check_pkgbuild_validity

                    manage-pkgbuild-keys --export

                    pkg2yaml -o "${SRCINFO}"

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

                    upgrade_db

                    update_yaml_add "${REBUILD}" "${ADD}" "${NOCHECK}" "${DEST}"

                    update_yaml_team "${team}"

                    if [[ -z ${AGENT} ]]; then
                        AGENT=${AGENT_MAP["${team}"]}
                    fi
                    write_jenkinsfile "${AGENT}"

                    local commit_msg
                    commit_msg=$(get_commit_msg 'add' "${DEST}")

                    if [[ -f .SRCINFO ]]; then
                        rm .SRCINFO
                    fi

                    if [[ -n $(git status --porcelain --untracked-files=no) ]]; then

                        stat_busy 'Staging files'
                        ( git ls-files -z --others --exclude-standard
                          git ls-files -z --modified ) | xargs -r0 -- git add --
                        git ls-files -z --deleted | xargs -r0 -- git rm --
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
