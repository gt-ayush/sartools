#!/hint/bash
#
# SPDX-License-Identifier: GPL-3.0-or-later

#{{{ gitea api

get_compliant_name() {
    local name=$1
    printf "%s\n" "${name}" \
    | sed -E 's/([a-zA-Z0-9]+)\+([a-zA-Z]+)/\1-\2/g' \
    | sed -E 's/\+/plus/g' \
    | sed -E 's/[^a-zA-Z0-9_\-\.]/-/g' \
    | sed -E 's/[_\-]{2,}/-/g'
}

api_put() {
    curl -s -X PUT "$@"
}

api_delete() {
    curl -s -X DELETE "$@"
}

api_post() {
    curl -s -X POST "$@"
}

api_patch() {
    curl -s -X PATCH "$@"
}

api_get() {
    curl -s -X GET "$@"
}

add_team_to_repo() {
    local pkgbase="$1"
    local team="$2"
    local url
    url="${API_URL}/repos/${GIT_ORG}/$pkgbase/teams/$team"

    stat_busy "Adding team ($team) to package repo [$pkgbase]"
    api_put "$url" \
        -H "accept: application/json" \
        -H "Authorization: token ${GIT_TOKEN}"
    stat_done
}

remove_team_from_repo() {
    local pkgbase="$1"
    local team="$2"
    local url
    url="${API_URL}/repos/${GIT_ORG}/$pkgbase/teams/$team"

    stat_busy "Removing team ($team) from package repo [$pkgbase]"
    api_delete "$url" \
        -H "accept: application/json" \
        -H "Authorization: token ${GIT_TOKEN}"
    stat_done
}

create_repo() {
    local pkgbase="$1"
    local url json
    url="${API_URL}/org/${GIT_ORG}/repos"
    json="{ \"auto_init\": true, \"name\": \"$pkgbase\", \"gitignores\": \"ArtixLinuxPackages\", \"readme\": \"Default\" }"

    stat_busy "Create package repo [$pkgbase] in org (${GIT_ORG})"
    api_post "$url" \
        -H "accept: application/json" \
        -H "content-type: application/json" \
        -H "Authorization: token ${GIT_TOKEN}" \
        -d "$json"
    stat_done
}

transfer_repo() {
    local pkgbase="$1"
    local new_owner="$2"
    local json url
    json="{ \"new_owner\": \"$new_owner\",  \"team_ids\": [], \"archived\": \"true\" }"
    url="${API_URL}/repos/${GIT_ORG}/$pkgbase/transfer"

    stat_busy "Transfer package repo [$pkgbase] in org ($new_owner)"
    api_post "$url" \
        -H "accept: application/json" \
        -H "Content-Type: application/json" \
        -H "Authorization: token ${GIT_TOKEN}" \
        -d "$json"
    stat_done
}

list_all_repos() {
    local url
    url="${API_URL}/orgs/${GIT_ORG}/repos?limit=10000"

    stat_busy "Query all packages"
    api_get "$url" \
        -H "accept: application/json"
    stat_done
}

add_topic() {
    local url
    local pkgbase="$1"
    local topic="$2"
    url="${API_URL}/repos/${GIT_ORG}/$pkgbase/topics/$topic"

    stat_busy "Add topic ($topic) to [$pkgbase]"
    api_put "$url" \
        -H "accept: application/json" \
        -H "Authorization: token ${GIT_TOKEN}"
    stat_done
}

remove_topic() {
    local url
    local pkgbase="$1"
    local topic="$2"
    url="${API_URL}/repos/${GIT_ORG}/$pkgbase/topics/$topic"

    stat_busy "Remove topic ($topic) from [$pkgbase]"
    api_delete "$url" \
        -H "accept: application/json" \
        -H "Authorization: token ${GIT_TOKEN}"
    stat_done
}

search_topic() {
    local search="$1"
    local url args
    args="topic=true&includeDesc=false&private=false&is_private=false"
    args+="&template=false&archived=false&order=asc&limit=10000"
    url="${API_URL}/repos/search?q=${search}&${args}"

    stat_busy "Query for topic (${search})"
    api_get "$url" \
        -H 'accept: application/json'
    stat_done
}

list_repo_teams() {
    local pkgbase="$1"
    local url
    url="${API_URL}/repos/${GIT_ORG}/$pkgbase/teams"

    stat_busy "List repo teams [$pkgbase]"
    api_get "$url" \
        -H 'accept: application/json' \
        -H "Authorization: token ${GIT_TOKEN}"
    stat_done
}

check_repo_team() {
    local pkgbase="$1"
    local team="$2"
    local url
    url="${API_URL}/repos/${GIT_ORG}/$pkgbase/teams/$team"

    stat_busy "Check if team ($team) is assigned to [$pkgbase]"
    api_get "$url" \
        -H 'accept: application/json' \
        -H "Authorization: token ${GIT_TOKEN}"
    stat_done
}

archive_repo() {
    local pkgbase="$1"
    local org="$2"
    local url
    local json
    url="${API_URL}/repos/$org/$pkgbase"
    json="{ \"archived\": true }"

    stat_busy "Archive repo [$pkgbase] in org ($org)"
    api_patch "$url" \
        -H "accept: application/json" \
        -H "content-type: application/json" \
        -H "Authorization: token ${GIT_TOKEN}" \
        -d "$json"
    stat_done
}

remove_all_topics() {
    local pkgbase="$1"
    local org="$2"
    local url
    local json
    url="${API_URL}/repos/$org/$pkgbase/topics"
    json="{ \"topics\": [] }"

    stat_busy "Delete all topics from [$pkgbase]"
    api_put "$url" \
        -H 'accept: application/json' \
        -H 'Content-Type: application/json' \
        -H "Authorization: token ${GIT_TOKEN}" \
        -d "$json"
    stat_done
}

#}}}
