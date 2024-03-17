#! /usr/bin/env bash
# shellcheck disable=SC2059

# Entry point for the `ls` command
exec_ls() {
  local ids names role count

  # Get all running containers for the current environment as JSON
  json="[$(docker ps -f "label=local.stacks.$ENV_ID_LABEL=$REGTEST_ENV_ID" --format "json" | tr '\n' ',' | sed 's/,*$//g')]"
  
  # Use 'jq' to extract the container IDs and names
  ids="$( echo "$json" | jq '.[] .ID' )"
  names="$( echo "$json" | jq '.[] .Names' )"

  # Convert the newline-separated strings into arrays
  readarray -t ids <<<"$ids" 2>&1 /dev/null
  readarray -t names <<<"$names" 2>&1 /dev/null

  # Count the number of active services (excluding the environment service)
  count="$((${#ids[@]} - 1))"

  if [ $count -eq 0 ]; then
    echo "There are currently no active services"
    exit 0
  fi
  
  # Print the table header
  printf "${CYAN}%-40s" "NAME"
  printf "%-18s" "ROLE"
  printf 'VERSION'
  printf "${NC}\n"

  # Print the services
  for (( i=0; i<${#ids[@]}; i++ )) ; do
    # Fetch the role for the current container id
    role="$( get_role_for_container_id "${ids[$i]}" )"

    # Skip the environment service
    if [ "$role" = "environment" ]; then
      continue
    fi

    # Fetch the node version, leader status and process for the current container id
    node_version="$( get_stacks_label_for_container_id "${ids[$i]}" "$NODE_VERSION_LABEL" )"
    is_leader="$( get_stacks_label_for_container_id "${ids[$i]}" "$LEADER_LABEL" )"
    process="$( get_stacks_process_for_container_id "${ids[$i]}" )"
    
    # Name
    printf '%-40s' "$( trim_quotes "${names[$i]}" )"

    # Role
    if [ "$is_leader" = "true" ]; then
      pad 18 "$( printf "$role (${BOLD}leader${NC})" )"
    else
      pad 18 "$role"
    fi

    # Version
    if [ -z "$process" ]; then
      printf "$node_version"
    elif [ "$node_version" != "$process" ]; then
      printf "${GRAY}$node_version ⇾ ${NC}${BOLD}$process${NC}"
    elif [ "$process" = "" ]; then
      printf "%s" "--"
    else
      printf "$process"
    fi

    # Newline
    printf '\n'
  done

  echo
  echo "This environment has a total of $count active services (excluding hidden)"
}