#! /usr/bin/env bash
# shellcheck source=constants.sh
# shellcheck source=vars.sh

# Polls the running containers for this environment and updates the environment 
# data. This copies the `host` file from the local environment to the container
# and the `container` file from the container to the local environment. A
# rudimentary communication protocol between host and container.
poll_containers() {
    local json ids dir id role

    json="[$(docker ps -f "label=local.stacks.$ENV_ID_LABEL=$REGTEST_ENV_ID" --format "json" | tr '\n' ',' | sed 's/,*$//g')]"
    ids="$( echo "$json" | jq '.[] .ID' )"
    readarray -t ids <<<"$ids" 2>&1 /dev/null

    for (( i=0; i<${#ids[@]}; i++ )) ; do
        id="$( trim_quotes "${ids[$i]}" )"
        role="$( get_role_for_container_id "${ids[$i]}" )"

        if [ "$role" != "node" ]; then
            continue
        fi

        dir="./environments/$REGTEST_ENV_ID/run/$id"

        mkdir -p "$dir"
        touch -a "$dir/host"

        docker exec "$id" touch "/stacks/run/.copying"
        docker cp "$dir/host" "$id:/stacks/run/host"
        docker cp "$id:/stacks/run/container" "$dir/container"
        docker exec "$id" rm "/stacks/run/.copying"
    done
}

# Generates a docker-compose-friendly string of services based on the current
# start flags. This can then be used together with i.e. `docker compose up`, 
# `docker compose down`, etc.
get_services_string() {
    services=""

    if [ "$STACKS_24_LEADER" -eq "$TRUE" ]; then
        services="$services stacks-2.4-leader-node"
    fi

    if [ "$STACKS_24_FOLLOWER" -eq "$TRUE" ]; then
        services="$services stacks-2.4-follower-node"
    fi

    if [ "$STACKS_NAKA_LEADER" -eq "$TRUE" ]; then
        services="$services stacks-naka-leader-node"
    fi

    if [ "$STACKS_NAKA_FOLLOWER" -eq "$TRUE" ]; then
        services="$services stacks-naka-follower-node"
    fi

    echo "$services" | xargs echo -n
}

# Retrieves the current environment ID from the running environment.
get_current_environment_id() {
    REGTEST_ENV_ID="$(docker ps -f 'label=local.stacks.role=environment' --format "{{.Labels}}" | grep -Po "(?<=local\.stacks\.environment_id=)[^,]*")"
}

# Retrieves the role for a container ID.
get_role_for_container_id() {
    local container_id

    get_stacks_label_for_container_id "$1" "$ROLE_LABEL"
}

# Retrieves the value of the specified `local.stacks.*` label for a container ID.
get_stacks_label_for_container_id() {
    local container_id label

    container_id=$( echo "$1" | tr -d '"' )
    label=$( echo "$2" | tr -d '"' )
    #echo "container_id=$container_id, label=$label" 1>&2
    docker ps -f "id=$container_id" --format "{{.Labels}}" | grep -Po "(?<=local\.stacks\.$label=)[^,]*"
}

# Retrieves the active process for a container ID.
get_stacks_process_for_container_id() {
    local container_id result

    container_id=$( echo "$1" | tr -d '"' )
    result=$( docker top "$container_id" o pid,cmd | sed '1d' | grep -oP '(?<=stacks-node-)[\w-\._]+' )
    echo "$result"
}