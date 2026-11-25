#!/bin/bash
#
# SPDX-License-Identifier: GPL-3.0-or-later

get_packager_name() {
    local packager=$1
    local packager_pattern="(.+) <(.+@.+)>"
    local name

    if [[ ! $packager =~ $packager_pattern ]]; then
        return 1
    fi

    name=$(echo "${packager}"|sed -E "s/${packager_pattern}/\1/")
    printf "%s" "${name}"
}

get_packager_email() {
    local packager=$1
    local packager_pattern="(.+) <(.+@.+)>"
    local email

    if [[ ! $packager =~ $packager_pattern ]]; then
        return 1
    fi

    email=$(echo "${packager}"|sed -E "s/${packager_pattern}/\2/")
    printf "%s" "${email}"
}

is_packager_name_valid() {
    local packager_name=$1
    if [[ -z ${packager_name} ]]; then
        return 1
    elif [[ ${packager_name} == "John Tux" ]]; then
        return 1
    elif [[ ${packager_name} == "Unknown Packager" ]]; then
        return 1
    fi
    return 0
}

is_packager_email_official() {
    local packager_email=$1
    if [[ -z ${packager_email} ]]; then
        return 1
    elif [[ $packager_email =~ .+@artixlinux.org ]]; then
        return 0
    fi
    return 1
}

# Load makepkg.conf once to make variables available
_makepkg_config_loaded=false
makepkg_load_config() {
    if $_makepkg_config_loaded; then
        return
    fi
    _makepkg_config_loaded=true
    source /usr/share/makepkg/util/config.sh
    # shellcheck disable=2119
    load_makepkg_config
}

makepkg_generate_integrity() {
    if [[ -z ${ARTOOLS_GENERATE_INTEGRITY} ]]; then
        [[ -z ${WORKDIR:-} ]] && setup_workdir
        export WORKDIR ARTOOLS_INCLUDE_MESSAGE_SH
        bash -$- -c "ARTOOLS_GENERATE_INTEGRITY=1; source '${BASH_SOURCE[0]}' && ${FUNCNAME[0]}"
        return
    fi
    (
    # shellcheck disable=SC2030 disable=SC2031
    export LIBMAKEPKG_LINT_PKGBUILD_SH=1
    lint_pkgbuild() { :; }

    set +e -- --geninteg
    # shellcheck source=/usr/bin/makepkg
    source "$(command -v makepkg)"
    )
}

