#!/hint/bash
#
# SPDX-License-Identifier: GPL-3.0-or-later

readonly ARTIX_DB=(
    system-goblins
    system-gremlins
    system
    world-goblins
    world-gremlins
    world
    lib32-goblins
    lib32-gremlins
    lib32
    galaxy-goblins
    galaxy-gremlins
    galaxy
)

readonly ARTIX_DB_MAP=(
    goblins
    gremlins
    stable
)

readonly AGENTS=(
    orion
    taurus
)

readonly ARTIX_TEAMS=(
    "${ARTIX_DB[2]}"
    "${ARTIX_DB[5]}"
    "${ARTIX_DB[8]}"
    "${ARTIX_DB[11]}"
)

declare -A AGENT_MAP=(
    ["${ARTIX_TEAMS[0]}"]=${AGENTS[0]}
    ["${ARTIX_TEAMS[1]}"]=${AGENTS[0]}
    ["${ARTIX_TEAMS[2]}"]=${AGENTS[1]}
    ["${ARTIX_TEAMS[3]}"]=${AGENTS[1]}
)

readonly REPO_DB='.artixlinux/pkgbase.yaml'

readonly REPO_CI='.artixlinux/Jenkinsfile'

readonly SRCINFO='.artixlinux/srcinfo.yaml'


print_package_names() {
    local version
    local array
    local architecture pkg
    version=$(get_full_version)
    for pkg in "${pkgname[@]}"; do
        architecture=$(get_pkg_arch "${pkg}")
        array="${array:-}${array:+,} $pkg-$version-$architecture$PKGEXT"
    done
    printf "%s\n" "[${array}]"
}

print_debug_package_names() {
    local version
    local architecture
    version=$(get_full_version)
    if check_option "debug" "y" && check_option "strip" "y"; then
        architecture=$(get_pkg_arch)
        printf "[%s-%s-%s-%s%s]\n" "$pkgbase" "debug" "$version" "$architecture" "$PKGEXT"
    else
        printf "%s\n" "[]"
    fi
}

version_from_yaml() {
    local dest="$1"
    local version repo
    repo=".repos.${dest}"
    version=$(repo="${repo}" yq -r 'eval(strenv(repo)).version' "${REPO_DB}")
    printf "%s\n" "${version}"
}

to_bool() {
    local int="$1"
    case "${int}" in
        0) printf "false\n" ;;
        1) printf "true\n" ;;
    esac
}

get_commit_msg() {
    local action="$1"
    local dest="$2"
    local src="$3"
    local version

    case "${action}" in
        add|remove)
            version=$(version_from_yaml "${dest}")
            printf "[%s] '%s' %s\n" "${dest}" "${pkgbase}-${version}" "${action}"
        ;;
        move)
            version=$(version_from_yaml "${src}")
            printf "[%s] -> [%s] '%s' %s\n" "${src}" "${dest}" "${pkgbase}-${version}" "${action}"
        ;;
        update)
            printf "'%s' %s\n" "${pkgbase}" "${action}"
        ;;
    esac
}

create_repo_db() {
    [[ -d .artixlinux ]] || mkdir .artixlinux

    yq -n '"---"' > "${REPO_DB}"

    yq -P '
        .team = null |
        with(
        .actions;
            .addRepo = null |
            .removeRepo = null |
            .triggersBuild = false |
            .triggersRebuild = false |
            .triggersRepoAdd = false |
            .triggersRepoRemove = false |
            .triggersNoCheck = false ) |
            .repos = {}
        ' -i "${REPO_DB}"

    for r in "${ARTIX_DB[@]}"; do
        local repo
        repo=".repos.${r}" \
        yq -P '
            with(
            eval(strenv(repo));
                .version = null |
                .packages = [] |
                .debug = [] )
            ' -i "${REPO_DB}"
    done
}

update_yaml_team() {
    local team="${1:-${ARTIX_DB[5]}}"
    team="$team" yq -P '.team = env(team)' -i "${REPO_DB}"
}

update_yaml_add() {
    local rebuild="$1"
    local add="$2"
    local nocheck="$3"
    local dest="$4"

    local build=true

    rebuild=$(to_bool "${rebuild}")
    if ${rebuild}; then
        rebuild=true
        build=false
    fi

    add=$(to_bool "${add}")
    if ${add}; then
        local repo
        local pkgs
        local version
        local pkgfiles
        local debug_pkgfiles

        pkgs=$(print_package_names)

        debug_pkgs=$(print_debug_package_names)

        version=$(get_full_version)
        repo=".repos.${dest}"

        version="${version}" repo="${repo}" \
        pkgs="${pkgs}" debug_pkgs="${debug_pkgs}" \
        yq -P '
            with(
            eval(strenv(repo));
                .version = env(version) |
                .packages = env(pkgs) |
                .debug = env(debug_pkgs) )
            ' -i "${REPO_DB}"
    fi

    nocheck=$(to_bool "${nocheck}")

    nocheck="${nocheck}" add="${add}" \
    rebuild="${rebuild}" build="${build}" dest="${dest}" \
    yq -P '
        with(
        .actions;
            .addRepo = env(dest) |
            .removeRepo = null |
            .triggersBuild = env(build) |
            .triggersRebuild = env(rebuild) |
            .triggersRepoAdd = env(add) |
            .triggersRepoRemove = false |
            .triggersNoCheck = env(nocheck) )
        ' -i "${REPO_DB}"
}

update_yaml_commit() {
    local dest="$1"

    local repo
    repo=".repos.${dest}"

    repo="${repo}" dest="${dest}" \
    yq -P '
        with(
        .actions;
            .addRepo = null |
            .removeRepo = null |
            .triggersBuild = false |
            .triggersRebuild = false |
            .triggersRepoAdd = false |
            .triggersRepoRemove = false |
            .triggersNoCheck = false )
        ' -i "${REPO_DB}"
}

update_yaml_remove() {
    local dest="$1"

    local repo
    repo=".repos.${dest}"

    repo="${repo}" dest="${dest}" \
    yq -P '
        with(
        eval(strenv(repo));
            .version = null |
            .packages = [] |
            .debug = [] ) |
        with(
        .actions;
            .addRepo = null |
            .removeRepo = env(dest) |
            .triggersBuild = false |
            .triggersRebuild = false |
            .triggersRepoAdd = false |
            .triggersRepoRemove = true |
            .triggersNoCheck = false )
        ' -i "${REPO_DB}"
}

update_yaml_move() {
    local src="$1"
    local dest="$2"
    local pkgs
    local debug_pkgs
    local version
    local src_repo
    local dest_repo

    src_repo=".repos.${src}"
    dest_repo=".repos.${dest}"

    version=$(version_from_yaml "${src}")

    pkgs=$(src_repo="${src_repo}" yq -Pr -o json 'eval(strenv(src_repo)).packages' "${REPO_DB}")
    debug_pkgs=$(src_repo="${src_repo}" yq -Pr -o json 'eval(strenv(src_repo)).debug' "${REPO_DB}")

    src_repo="${src_repo}" dest_repo="${dest_repo}" \
    version="${version}" src=${src} dest="${dest}" \
    pkgs="${pkgs}" debug_pkgs="${debug_pkgs}" \
    yq -P '
        with(
        eval(strenv(src_repo));
            .version = null |
            .packages = [] |
            .debug = [] ) |
        with(
        eval(strenv(dest_repo));
            .version = env(version) |
            .packages = env(pkgs) |
            .debug = env(debug_pkgs) ) |
        with(
        .actions;
            .addRepo = env(dest) |
            .removeRepo = env(src) |
            .triggersBuild = false |
            .triggersRebuild = false |
            .triggersRepoAdd = true |
            .triggersRepoRemove = true |
            .triggersNoCheck = false )
        ' -i "${REPO_DB}"
}

team_from_yaml() {
    local team
    team=$(yq -rP '.team' "${REPO_DB}")
    printf "$team"
}

detect_team() {
    local team

    for repo in "${ARTIX_TEAMS[@]}"; do
        local key res
        res=$(key=".repos.$repo" yq -rP 'eval(strenv(key)) | .version' "${REPO_DB}")
        if [[ "${res}" != "null" ]]; then
            team=${repo}
        fi
    done
    printf "%s\n" "$team"
}

show_agent() {
    local agent
    local runon
    local ci
    local branch
    agent="${AGENTS[0]}"
    ci=$(head -n 1 "${REPO_CI}" | cut -d "'" -f2)
    branch=${ci#*@}

    if [[ -n "$branch" ]]; then
        agent="$branch"
    fi

    if [[ "$agent" != "${CI_MODE}" ]]; then
        runon=$(head -n 5 "${REPO_CI}" | cut -sd '=' -f2 | cut -d "'" -f2)
        if [[ -z "$runon" ]]; then
            runon="$agent"
        fi
    else
        runon=$(head -n 5 "${REPO_CI}" | cut -sd '=' -f2 | cut -d "'" -f2)
    fi

    msg2 "agent: %s" "$runon"
    msg2 "branch: %s" "$branch"
}

show_db() {
    show_agent
    if ! yq -r "${REPO_DB}" 1>/dev/null 2>/dev/null; then
        die "${REPO_DB} invalid!"
    fi
    yq -rP 'with_entries(select(.key == "team"))' "${REPO_DB}"
    yq -rP '.repos | with_entries(select(.value.version))' "${REPO_DB}"
    return 0
}

write_jenkinsfile() {
    local agent="$1"
    {
        printf "@Library('artix-ci@%s') _\n" "${CI_MODE}"
        printf '\n'
        printf 'import org.artixlinux.RepoPackage\n'
        printf '\n'
        printf "String runOn = '%s'\n" "${agent}"
        printf '\n'
        printf 'PackagePipeline(new RepoPackage(this), runOn)\n'
    } > "${REPO_CI}"
}
