#! /usr/bin/env bash
# shellcheck source=constants.sh
# shellcheck source=lib.sh

# Polls the running containers for this environment and updates the environment 
# data. This copies the `host` file from the local environment to the container
# and the `container` file from the container to the local environment. A
# rudimentary communication protocol between host and container.
poll_containers() {
  local json ids dir id role result

  json="[$(docker ps -f "label=local.stacks.$ENV_ID_LABEL=$REGTEST_ENV_ID" \
    --format "json" | tr '\n' ',' | sed 's/,*$//g')]"
  ids="$( echo "$json" | jq '.[] .ID' )"
  readarray -t ids <<<"$ids" 2>&1 /dev/null

  for (( i=0; i<${#ids[@]}; i++ )) ; do
    id="$( trim_quotes "${ids[$i]}" )"
    role="$( get_role_for_container_id "${ids[$i]}" )"

    if [ "$role" != "node" ]; then
      continue
    fi

    dir="./environments/$REGTEST_ENV_ID/run/$id"

    mkdir -p "$dir" "$dir/inbox" "$dir/outbox"
    touch -a "$dir/host"

    if ! docker exec "$id" touch "/stacks/run/.lock" > /dev/null 2>&1; then
      log "Failed to lock container $id"
    fi

    if ! docker cp "$dir/host" "$id:/stacks/run/host" >> "$ENV_LOG_FILE" 2>&1; then
      log "Failed to copy host file to container $id"
    fi
    if ! docker cp "$id:/stacks/run/container" "$dir/container" >> "$ENV_LOG_FILE" 2>&1; then
      log "Failed to copy container file from container $id"
    fi
    for outfile in "$dir/outbox/"*; do
      outfile=$(basename "$outfile")
      if ! docker cp "$dir/outbox/$outfile" "$id:/stacks/inbox/$outfile" >> "$ENV_LOG_FILE" 2>&1; then
        log "Failed to copy outbox files to container $id"
      else
        rm "$dir/outbox/$outfile"
      fi
    done

    if ! docker exec "$id" rm "/stacks/run/.lock">> "$ENV_LOG_FILE" 2>&1; then
      log "Failed to unlock container $id"
    fi
  done
}

# Copies the default contracts from './contracts' to the container with
# the specified id.
#
# @param $1 - The container id
copy_default_contracts_to_container() {
  local id file path
  id="$1"
  echo "Installing default contracts..."

  docker exec "$id" touch "/stacks/inbox/.lock"
  for path in ./contracts/*.deploy; do
    file=$(basename "$path")
    echo "‣ Installing contract: $file"
    docker cp "$dir/host" "$id:/stacks/inbox/$file"
  done
  docker exec "$id" rm "/stacks/inbox/.lock"
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
  ENV_LOGS_DIR="./environments/$REGTEST_ENV_ID/logs"
  ENV_RUN_DIR="./environments/$REGTEST_ENV_ID/run"
  # shellcheck disable=SC2034
  ENV_LOG_FILE="$ENV_LOGS_DIR/regtest.log"
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
  docker ps -f "id=$container_id" --format "{{.Labels}}" \
    | grep -Po "(?<=local\.stacks\.$label=)[^,]*"
}

# Retrieves the active process for a container ID.
get_stacks_process_for_container_id() {
  local container_id result

  container_id=$( echo "$1" | tr -d '"' )
  result=$( docker top "$container_id" o pid,cmd | sed '1d' \
    | grep -oP '(?<=stacks-node-)[\w-\._]+' )
  echo "$result"
}

delete_all_environment_networks() {
  local -a network_names
  network_names=$( \
    docker network ls -f 'label=local.stacks.environment_id' --format "{{.Name}}" \
  )
  #readarray -t network_names <<<"$network_names" 2>&1 /dev/null
  echo "$network_names"
}

get_random_stacks_node_container_id() {
  local leader filter json ids id
  leader=${1:-}

  filter="-f 'label=local.stacks.role=node' -f 'label=local.stacks.$ENV_ID_LABEL=$REGTEST_ENV_ID'"

  if [ "$leader" = "$TRUE" ]; then
    filter="$filter -f 'label=local.stacks.leader=true'"
  elif [ "$leader" = "$FALSE" ]; then
    filter="$filter -f 'label=local.stacks.leader=false'"
  fi
  
  if [ -z "$REGTEST_ENV_ID" ]; then
    echo "No active environment"
    exit 0
  fi

  # Get all running containers for the current environment as JSON
  cmd="docker ps $filter --format 'json' | tr '\n' ',' | sed 's/,*$//g'"
  json="[$( bash -c "$cmd" )]"

  # Use 'jq' to extract the container IDs
  ids="$( echo "$json" | jq '.[] .ID' )"

  # Convert the newline-separated strings into arrays
  readarray -t ids <<<"$ids" 2>&1 /dev/null

  # Get a random index from the array of ids
  index=$((RANDOM % ${#ids[@]}))
  id="${ids[$index]}"

  trim_quotes "$id"
}