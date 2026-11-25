#!/hint/bash
#
# SPDX-License-Identifier: GPL-3.0-or-later


upgrade_db() {
    local d
    for db in "${ARTIX_DB[@]}"; do
        local res
        res=$(d=".repos.$db" yq 'eval(strenv(d)) | has("debug")' "${REPO_DB}")
        if ! "${res}"; then
            d=".repos.$db" \
            yq 'eval(strenv(d)).debug = []' -i "${REPO_DB}"
        fi
    done

    if $(yq '. | has("pkgbase") ' "${REPO_DB}"); then
        yq 'del(.pkgbase)' -i "${REPO_DB}"
    fi
}
