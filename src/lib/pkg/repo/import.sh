#!/hint/bash
#
# SPDX-License-Identifier: GPL-3.0-or-later

[[ -z ${ARTOOLS_INCLUDE_REPO_IMPORT_SH:-} ]] || return 0
ARTOOLS_INCLUDE_REPO_IMPORT_SH=1

set -e

PATCHDIR=${PATCHDIR:-"${WORKSPACE_DIR}/artix-patches"}

declare -A arch_map=(
    ["archlinux-mirrorlist"]="pacman-mirrorlist"
    ["artix-rebuild-order"]="arch-rebuild-order"
    ["virtualbox-host-modules-artix"]="virtualbox-host-modules-arch"
)

update_patches(){
    if [[ ! -d "${PATCHDIR}" ]]; then
        # ${GIT_ORG}
        if ! git clone "${PATCH_URL}" "${PATCHDIR}"; then
            error "failed to clone %s" "${PATCHDIR}"
        fi
    else
        if ! git -C "${PATCHDIR}" pull; then
           error "Failed to pull artix-patches"
        fi
    fi
}

patch_pkgbase(){
    local name="$1"
    local patches="${PATCHDIR}/patches/${name}"
    sed -e 's|arch-meson|artix-meson|' -i PKGBUILD

    if "${PATCH_MAINTAINER}" && [ -n "${PACKAGER}" ]; then
        sed -e 's|# Maintainer:|# Contributor:|' -i PKGBUILD
        printf '%s\n%s\n' "# Maintainer: ${PACKAGER}" "$(cat "PKGBUILD")" >"PKGBUILD"
    fi

    if [ -d "${patches}" ]; then
        if [ -f "${patches}/env.txt" ]; then
            while read -r line; do
                IFS="=" read -r key value <<< "$line"
                if [[ -z "${key}" ]] || [[ -z "${value}" ]]; then
                    die "Invalid key value pair in env.txt"
                fi
                if declare -p "${key}" &> /dev/null; then
                    die "Environment variable %s already exists." "${key}"
                fi
                export "${key}=${value}"
            done < "${patches}/env.txt"
        fi
        for file in "${patches}"/*; do
            if [ -x "${file}" ]; then
                echo "$> ${name}/$(basename "${file}")"
                "${file}" "${TREE_DIR_ARTIX}/${name}"
            elif [[ "${file}" == *.diff ]]; then
                echo "$> git apply ${name}/$(basename "${file}")"
                git -C "${TREE_DIR_ARTIX}/${name}" apply "${file}"
            fi
        done
    fi
}

artixpkg_repo_import_usage() {
    local -r COMMAND=${_ARTOOLS_COMMAND:-${BASH_SOURCE[0]##*/}}
    cat <<- _EOF_
    Usage: ${COMMAND} [OPTIONS] [PKGBASE]...

    OPTIONS
        --tag TAG          Switch the current workspace to a specified version tag
        --nexttag          Import oldest tag that is newer than the PKGBUILD
        --del              Delete files before rsync import
        -n --no-patch      No patch import
        -h, --help         Show this help text

    EXAMPLES
        $ ${COMMAND} libfoo
        $ ${COMMAND} --tag TAG libfoo
        $ ${COMMAND} --tag TAG --del libfoo
        $ ${COMMAND} --no-patch libfoo
_EOF_
}

artixpkg_repo_import() {
    if (( $# < 1 )); then
        artixpkg_repo_import_usage
        exit 0
    fi

    # options
    local pkgbases=()
    local pkgbase
    local TAG
    local NP=0
    local rsync_args=()
    rsync_args+=(
        -axcihW
        --no-R
        --no-implied-dirs
        --exclude '.artixlinux'
        --exclude '.git'
        --exclude '.gitignore'
        --exclude 'README.md'
        --exclude '*.service'
        --exclude '.SRCINFO'
        --exclude '*.socket'
        --exclude '*.timer'
    )

    while (( $# )); do
        case $1 in
            --tag)
                (( $# <= 1 )) && die "missing argument for %s" "$1"
                TAG="$2"
                shift 2
            ;;
            --tag=*)
                TAG="${1#*=}"
                shift
            ;;
            --nexttag)
                TAG=':next?'
                shift
                ;;
            --del)
                rsync_args+=(--delete-before)
                shift
            ;;
            -n|--no-patch)
                NP=1
                shift
            ;;
            -h|--help)
                artixpkg_repo_import_usage
                exit 0
            ;;
            -*)
                die "invalid argument: %s" "$1"
            ;;
            *)
                break
            ;;
        esac
    done

    if ! (( NP )); then
        update_patches
    fi

    pkgbases+=("$@")

    for pkgbase in "${pkgbases[@]}"; do

        if [[ -d "${pkgbase}" ]];then

            if [[ ! -d "${pkgbase}/.git" ]]; then
                error "Not a Git repository: ${pkgbase}"
                continue
            fi
            ( cd "${pkgbase}" || return

                upstream="${arch_map["$pkgbase"]:-$pkgbase}"

                stat_busy "Checking for upstream url"
                if ! git config get remote.upstream.url &>/dev/null; then
                    git remote add upstream "${GIT_UPSTREAM_URL}/${upstream}".git
                fi
                stat_done

                stat_busy "Fetching upstream tags"
                git fetch -fq --prune --tags upstream main
                stat_done

                local latest version
                latest=$(git describe --tags FETCH_HEAD)

                case $TAG in
                    ':next?')
                        local curpkg readtag
                        curpkg=$(. PKGBUILD; echo "${epoch+$epoch-}${pkgver}-${pkgrel}")
                        while IFS=$'\t' read -r _ readtag && readtag=${readtag#refs/tags/} && [[ "$(vercmp "$readtag" "$curpkg")" -gt 0 ]]; do
                            version="$readtag"
                        done < <(git ls-remote --tags --refs --sort -taggerdate upstream)
                        ;;
                    '') version="$latest" ;;
                    *) version="$TAG" ;;
                esac

                if no_remote_changes; then
                    msg "Querying ${pkgbase} ..."
                    if ! show_db; then
                        warning "Could not query ${REPO_DB}"
                    fi

                    git checkout -q "${version}" -b "${version}"
                    local temp
                    temp=$(mktemp -d --tmpdir "${pkgbase}.XXXXXXXXXX")

                    rsync "${rsync_args[@]}" -q "$(pwd)"/ "${temp}"/
                    git checkout -q master
                    git branch -q -D "${version}"

                    msg "Importing upstream changeset for ${version}"
                    rsync "${rsync_args[@]}" "${temp}"/ "$(pwd)"/

                    if ! (( NP )); then
                        msg2 "Patching ${pkgbase} ..."
                        patch_pkgbase "${pkgbase}"
                    fi
                    git --no-pager diff PKGBUILD
                fi
            )
        fi

    done
}
