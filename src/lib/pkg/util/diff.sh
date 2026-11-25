#!/hint/bash
#
# SPDX-License-Identifier: GPL-3.0-or-later

#{{{ functions

pkgver_equal() {
    if [[ $1 = *-* && $2 = *-* ]]; then
        # if both versions have a pkgrel, then they must be an exact match
        [[ $1 = "$2" ]]
    else
        # otherwise, trim any pkgrel and compare the bare version.
        [[ ${1%%-*} = "${2%%-*}" ]]
    fi
}

shopt -s extglob

find_cached_package() {
    local searchdirs=("$PWD" "$PKGDEST") results=()
    local targetname=$1 targetver=$2 targetarch=$3
    local dir pkg packages pkgbasename name ver rel arch r results

    for dir in "${searchdirs[@]}"; do
        [[ -d $dir ]] || continue

        shopt -s extglob nullglob
        mapfile -t packages < <(printf "%s\n" "$dir"/"${targetname}"-"${targetver}"-*"${targetarch}".pkg.tar?(.!(sig|*.*)))
        shopt -u extglob nullglob

        for pkg in "${packages[@]}"; do
            [[ -f $pkg ]] || continue

            # avoid adding duplicates of the same inode
            for r in "${results[@]}"; do
                [[ $r -ef $pkg ]] && continue 2
            done

            # split apart package filename into parts
            pkgbasename=${pkg##*/}
            pkgbasename=${pkgbasename%.pkg.tar*}

            arch=${pkgbasename##*-}
            pkgbasename=${pkgbasename%-"$arch"}

            rel=${pkgbasename##*-}
            pkgbasename=${pkgbasename%-"$rel"}

            ver=${pkgbasename##*-}
            name=${pkgbasename%-"$ver"}

            if [[ $targetname = "$name" && $targetarch = "$arch" ]] &&
                pkgver_equal "$targetver" "$ver-$rel"; then
                results+=("$pkg")
            fi
        done
    done

    case ${#results[*]} in
        0)
            return 1
        ;;
        1)
            printf '%s\n' "${results[0]}"
            return 0
        ;;
        *)
            error 'Multiple packages found:'
            printf '\t%s\n' "${results[@]}" >&2
            return 1
        ;;
    esac
}

shopt -u extglob

#}}}
