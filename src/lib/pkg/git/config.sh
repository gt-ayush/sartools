#!/bin/bash
#
# SPDX-License-Identifier: GPL-3.0-or-later

[[ -z ${ARTOOLS_INCLUDE_GIT_CONFIG_SH:-} ]] || return 0
ARTOOLS_INCLUDE_GIT_CONFIG_SH=1

# shellcheck source=src/lib/pkg/db/db.sh
source "${LIBDIR}"/pkg/db/db.sh
# shellcheck source=src/lib/pkg/util/packager.sh
source "${LIBDIR}"/pkg/util/packager.sh

set -e


artixpkg_git_config_usage() {
    local -r COMMAND=${_ARTOOLS_COMMAND:-${BASH_SOURCE[0]##*/}}
    cat <<- _EOF_
    Usage: ${COMMAND} [OPTIONS] [PKGBASE]...

    OPTIONS
        --protocol https       Configure remote url to use https
        -j, --jobs N           Run up to N jobs in parallel (default: $(nproc))
        -h, --help             Show this help text

    EXAMPLES
        $ ${COMMAND} *
_EOF_
}

artixpkg_git_config() {
    # options
    local GIT_REPO_BASE_URL=${GIT_HTTPS}
    local official=0
    local proto=https
    local proto_force=0
    local jobs=
    jobs=$(nproc)
    local paths=()

    # variables
    local command=${_ARTOOLS_COMMAND:-${BASH_SOURCE[0]##*/}}
    local path realpath pkgbase
    local PACKAGER GPGKEY packager_name packager_email

    while (( $# )); do
        case $1 in
        -h|--help)
            artixpkg_git_config_usage
            exit 0
        ;;
        --protocol=https)
            proto_force=1
            shift
        ;;
        --protocol)
            (( $# <= 1 )) && die "missing argument for %s" "$1"
            if [[ $2 == https ]]; then
                proto_force=1
            else
                die "unsupported protocol: %s" "$2"
            fi
            shift 2
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
            paths=("$@")
            break
        ;;
        esac
    done

    # check if invoked without any path from within a packaging repo
    if (( ${#paths[@]} == 0 )); then
        if [[ -f PKGBUILD ]]; then
            paths=(".")
        else
            artixpkg_git_config_usage
            exit 1
        fi
    fi

    # Load makepkg.conf variables to be available for packager identity
    msg "Collecting packager identity from makepkg.conf"

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
            official=1
            if (( ! proto_force )); then
                proto=ssh
                GIT_REPO_BASE_URL="${GIT_SSH}/"
            fi
        fi
    fi

    msg2 "name    : ${packager_name:-${YELLOW}undefined${ALL_OFF}}"
    msg2 "email   : ${packager_email:-${YELLOW}undefined${ALL_OFF}}"
    msg2 "gpg-key : ${GPGKEY:-${YELLOW}undefined${ALL_OFF}}"
    if [[ ${proto} == ssh ]]; then
        msg2 "protocol: ${GREEN}${proto}${ALL_OFF}"
    else
        msg2 "protocol: ${YELLOW}${proto}${ALL_OFF}"
    fi

    # parallelization
    if [[ ${jobs} != 1 ]] && (( ${#paths[@]} > 1 )); then
        if [[ -n ${BOLD} ]]; then
            export ARTOOLS_COLOR=always
        fi
        if ! parallel --bar --jobs "${jobs}" "${command}" ::: "${paths[@]}"; then
            die 'Failed to configure some packages, please check the output'
            exit 1
        fi
        exit 0
    fi

    for path in "${paths[@]}"; do
        if ! realpath=$(realpath -e "${path}"); then
            error "No such directory: ${path}"
            continue
        fi

        pkgbase=$(basename "${realpath}")
        pkgbase=${pkgbase%.git}
        msg "Configuring ${pkgbase}"

        if [[ ! -d "${path}/.git" ]]; then
            error "Not a Git repository: ${path}"
            continue
        fi
        ( cd "${path}" || return
            git config pull.rebase true
            git config branch.autoSetupRebase always


            # setup author identity
            if [[ -n ${packager_name} ]]; then
                git config user.name "${packager_name}"
                git config user.email "${packager_email}"
            fi

            # force gpg for official packagers
            if (( official )); then
                git config commit.gpgsign true
            fi

            # set custom pgp key from makepkg.conf
            if [[ -n $GPGKEY ]]; then
                git config commit.gpgsign true
                git config user.signingKey "${GPGKEY}"
            fi
            if [[ ! -f ${REPO_DB} ]]; then

                msg "Creating repo db ..."
                create_repo_db

                if [[ -f PKGBUILD ]]; then
                    pkg2yaml -o "${SRCINFO}"
                fi
                git add "${REPO_DB}"
                git commit -m "create repo db"

            fi

            if [[ ! -f ${REPO_CI} ]]; then

                [[ -d .artixlinux ]] || mkdir .artixlinux

                msg "Adding ci support ..."
                local agent
                agent="${AGENT_MAP["${TEAM_OPTS[1]}"]}"
                write_jenkinsfile "$agent"

                git add "${REPO_CI}"
                git commit -m "add ci support"

            fi

        )
    done
}
