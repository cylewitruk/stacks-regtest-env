#! /usr/bin/env bash

# shellcheck disable=SC2059

LC_CTYPE=en_US.UTF-8

TRUE=1
FALSE=0

export USER_ID
USER_ID="$(id -u)"
USER_NAME="$(id -un)"

export GROUP_ID
GROUP_ID="$(id -g)"
GROUP_NAME="$(id -gn)"

GRAY='\e[0;90m'        # Gray
BLACK='\e[0;30m'        # Black
RED='\e[0;31m'          # Red
GREEN='\e[0;32m'        # Green
YELLOW='\e[0;33m'       # Yellow
BLUE='\e[0;34m'         # Blue
PURPLE='\e[0;35m'       # Purple
CYAN='\e[0;36m'         # Cyan
WHITE='\e[0;37m'        # White
NC='\e[0m' # No Color
BOLD='\e[1m' # Bold
ITALIC='\e[3m' # Italic

# Variables to control which nodes to start
stacks_24_leader=$FALSE
stacks_24_follower=$FALSE
stacks_naka_leader=$FALSE
stacks_naka_follower=$FALSE
stacks_signer=$FALSE
start=$FALSE

ROLE_LABEL='role'
ENV_ID_LABEL='environment_id'
NODE_VERSION_LABEL='node_version'
LEADER_LABEL='leader'

# The main entry point for the program
main() {
    get_current_environment_id
    if [ -z "$REGTEST_ENV_ID" ]; then
        printf "${GRAY}Note: No active environment; some commands are unavailable.${NC}\n\n"
    else 
        printf "${GRAY}Regtest environment: $REGTEST_ENV_ID${NC}\n\n"
    fi

    case "$1" in 
        "start")
            shift
            exec_start "$@"
        ;;
        "build")
            docker compose build ;;
        "clean")
            local size
            size="$( du -sh ./environments | cut -f1 )"
            rm -rf ./environments/* 
            printf "Removed all regtest data from ./environments ($size reclaimed)\n"
        ;;
        "stop")
            docker compose down --remove-orphans --timeout 0
            unset REGTEST_ENV_ID
        ;;
        "ls") 
            exec_ls ;;
        "--help") 
            print_help ;;
        "test") 
            test ;;
    esac
}

# The entry point for the start command
exec_start() {
    if [ -n "$REGTEST_ENV_ID" ]; then
        printf "${RED}ERROR:${NC} An environment is already running - please stop it before starting a new one.\n"
        exit 0
    fi

    while test $# != 0; do
        #echo "testing: $1"
        case "$1" in 
            "--all-nodes")
                stacks_24_leader=$TRUE
                stacks_24_follower=$TRUE
                stacks_naka_leader=$TRUE
                stacks_naka_follower=$TRUE
                start=$TRUE
            ;;
            "--signer")
                stacks_signer=$TRUE
            ;;
            "--node")
                shift
                case "$1" in
                    "24-leader")
                        stacks_24_leader=$TRUE
                        start=$TRUE
                    ;;
                    "24-follower")
                        stacks_24_follower=$TRUE
                        start=$TRUE
                    ;;
                    "naka-leader")
                        stacks_naka_leader=$TRUE
                        start=$TRUE
                    ;;
                    "naka-follower")
                        stacks_naka_follower=$TRUE
                        start=$TRUE
                    ;;
                    *)
                        echo "Invalid node: $1"
                        exit 0
                    ;;
                esac
            ;;
            "--help")
                print_start_help
                exit 0
            ;;
            *) 
                print_start_help
                exit 0
            ;;
        esac
        shift
    done

    if [ $start -eq $FALSE ]; then
        print_start_help
        exit 0
    fi

    export REGTEST_ENV_ID
    REGTEST_ENV_ID="$(date +%Y%m%d%H%M%S)"

    mkdir -p "./environments/$REGTEST_ENV_ID/logs" "./environments/$REGTEST_ENV_ID/assets"

    echo "----------------------------------------"
    echo "Preparing to start Stacks regtest environment"
    echo "‣ User: $USER_NAME ($USER_ID) : $GROUP_NAME ($GROUP_ID)"
    echo "‣ Environment ID: $REGTEST_ENV_ID"
    echo "‣ Log Path: ./environments/$REGTEST_ENV_ID/logs"
    echo "‣ Assets Path: ./environments/$REGTEST_ENV_ID/assets"
    echo "----------------------------------------"

    services="$(get_services_string)"

    sh -c "docker compose build $services"
    docker compose up -d environment
    sh -c "docker compose up -d $services"

    if [ $stacks_signer -eq $TRUE ]; then
        echo "Starting the signer node..."
        docker compose up stacks-signer
    fi

    poll_containers
}

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

        docker cp "$dir/host" "$id:/stacks/run/host"
        docker cp "$id:/stacks/run/container" "$dir/container"
    done
}

exec_ls() {
    local ids names role count

    json="[$(docker ps -f "label=local.stacks.$ENV_ID_LABEL=$REGTEST_ENV_ID" --format "json" | tr '\n' ',' | sed 's/,*$//g')]"
    
    ids="$( echo "$json" | jq '.[] .ID' )"
    names="$( echo "$json" | jq '.[] .Names' )"

    readarray -t ids <<<"$ids" 2>&1 /dev/null
    readarray -t names <<<"$names" 2>&1 /dev/null

    count="$((${#ids[@]} - 1))"

    if [ $count -eq 0 ]; then
        echo "There are currently no active services"
        exit 0
    fi
    
    printf "${CYAN}%-40s" "NAME"
    printf "%-18s" "ROLE"
    printf 'VERSION'
    printf "${NC}\n"

    for (( i=0; i<${#ids[@]}; i++ )) ; do
        role="$( get_role_for_container_id "${ids[$i]}" )"

        if [ "$role" = "environment" ]; then
            continue
        fi

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

        # Active (from)
        if [ "$node_version" != "$process" ]; then
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

trim_quotes() {
    echo "$1" | tr -d '"'
}

# Generates a docker-compose-friendly string of services based on the current
# start flags. This can then be used together with i.e. `docker compose up`, 
# `docker compose down`, etc.
get_services_string() {
    services=""

    if [ $stacks_24_leader -eq $TRUE ]; then
        services="$services stacks-2.4-leader-node"
    fi

    if [ $stacks_24_follower -eq $TRUE ]; then
        services="$services stacks-2.4-follower-node"
    fi

    if [ $stacks_naka_leader -eq $TRUE ]; then
        services="$services stacks-naka-leader-node"
    fi

    if [ $stacks_naka_follower -eq $TRUE ]; then
        services="$services stacks-naka-follower-node"
    fi

    echo "$services" | xargs echo -n
}

# Retrieves the current environment ID from the running environment.
get_current_environment_id() {
    REGTEST_ENV_ID="$(docker ps -f 'label=local.stacks.role=environment' --format "{{.Labels}}" | grep -Po "(?<=local\.stacks\.environment_id=)[^,]*")"
}

get_role_for_container_id() {
    local container_id
    get_stacks_label_for_container_id "$1" "$ROLE_LABEL"
}

get_stacks_label_for_container_id() {
    local container_id label
    container_id=$( echo "$1" | tr -d '"' )
    label=$( echo "$2" | tr -d '"' )
    #echo "container_id=$container_id, label=$label" 1>&2
    docker ps -f "id=$container_id" --format "{{.Labels}}" | grep -Po "(?<=local\.stacks\.$label=)[^,]*"
}

get_stacks_process_for_container_id() {
    local container_id result
    container_id=$( echo "$1" | tr -d '"' )
    result=$( docker top "$container_id" o pid,cmd | sed '1d' | grep -oP '(?<=stacks-node-)[\w-\._]+' )
    echo "$result"
}

pad() {
    local -i length width pad_right
    local -- str

    width=${1:?} # Mandatory column width
    str=${2:?} # Mandatory input string
    length=$( echo -e -n "$str" | sed "s/$(echo -e -n "\e")[^m]*m//g" | wc -c )
    pad_right=$((width - length))

    printf '%s%*s' "${str}" $pad_right ''
}

# Prints the help message for the main program
print_help() {
    cat << EOF
Usage: ./regtest.sh COMMAND [OPTIONS]

Available Commands:
    start           Start the regtest environment
    build           Build the regtest environment
    clean           Clean all regtest environments from ./environments
    stop            Stop the regtest environment
    ls              List all running services for the current environment

Available Options:
    --help          Print this help message
EOF
}

# Prints the help message for the start command.
print_start_help() {
    cat << EOF
Usage: ./regtest.sh start [OPTIONS]

Available Options:
    --all-nodes     Start all nodes
    --signer        Start the signer node
    --node <node>   Start a specific node [24-leader, 24-follower, naka-leader, naka-follower]
    --help          Print this help message
EOF
}

# ==============================================================================
# MAIN PROGRAM ENTRY POINT
# ==============================================================================

# We hide this way down here so that our order of declarations 
# above don't matter =)
main "$@"

