#!/hint/bash
#
# SPDX-License-Identifier: GPL-3.0-or-later

#{{{ pkg conf

prepare_dir(){
    [[ ! -d $1 ]] && mkdir -p "$1"
    return 0
}

if [[ -n $SUDO_USER ]]; then
    eval "USER_HOME=~$SUDO_USER"
else
    USER_HOME=$HOME
fi

USER_CONF_DIR="${XDG_CONFIG_HOME:-$USER_HOME/.config}/sartools"

prepare_dir "${USER_CONF_DIR}"

load_pkg_config(){

    local conf="$1/artools-pkg.conf"

    [[ -f "$conf" ]] || return 1

    # shellcheck source=config/conf/artools-pkg.conf
    [[ -r "$conf" ]] && source "$conf"

    CHROOTS_DIR=${CHROOTS_DIR:-'/var/lib/sartools'}

    WORKSPACE_DIR=${WORKSPACE_DIR:-"${USER_HOME}/sartools-workspace"}

    ARCH=${ARCH:-"$(uname -m)"}

    REPO=${REPO:-'world'}

    local -r git_domain="gitea.artixlinux.org"

    GIT_HTTPS=${GIT_HTTPS:-"https://${git_domain}"}

    readonly API_URL="${GIT_HTTPS}/api/v1"

    GIT_SSH=${GIT_SSH:-"gitea@${git_domain}"}

    GIT_TOKEN=${GIT_TOKEN:-''}

    GIT_ORG=${GIT_ORG:-'packages'}

    GIT_UPSTREAM_URL=${GIT_UPSTREAM_URL:-"https://gitlab.archlinux.org/archlinux/packaging/packages"}

    GIT_ORG_ARCHIVE=${GIT_ORG_ARCHIVE:-'landfill'}

    TREE_DIR_ARTIX=${TREE_DIR_ARTIX:-"${WORKSPACE_DIR}/artixlinux"}

    REPOS_ROOT=${REPOS_ROOT:-"${WORKSPACE_DIR}/repos"}

    REPOS_MIRROR=${REPOS_MIRROR:-'http://mirror1.artixlinux.org/repos'}

    DBEXT=${DBEXT:-'gz'}

    PATCH_MAINTAINER=${PATCH_MAINTAINER:-false}

    PATCH_URL=${PATCH_URL:-"${GIT_SSH}:artix/artix-patches.git"}

    PKGDEST_DBG=${PKGDEST_DBG:-"${WORKSPACE_DIR}/packages-debug"}

    CI_MODE=${CI_MODE:-"production"}

    return 0
}

#}}}

load_pkg_config "${USER_CONF_DIR}" || load_pkg_config "${SYSCONFDIR}"

prepare_dir "${REPOS_ROOT}"
prepare_dir "${TREE_DIR_ARTIX}"
