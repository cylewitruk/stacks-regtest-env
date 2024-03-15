#! /usr/bin/env bash
# shellcheck source-path=SCRIPTDIR/scripts
# shellcheck disable=SC2059

# Set the PWD for script imports to know where they're at.
PWD="$(pwd)"

# Imports
. ./scripts/constants.sh
. ./scripts/docker.sh
. ./scripts/vars.sh
. ./scripts/lib.sh

# Load build-time environment variables
read_env .env

# Main entry point for the program
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

# Entry point for the start command.
exec_start() {
    if [ -n "$REGTEST_ENV_ID" ]; then
        printf "${RED}ERROR:${NC} An environment is already running - please stop it before starting a new one.\n"
        exit 0
    fi

    while test $# != 0; do
        #echo "testing: $1"
        case "$1" in 
            "--all-nodes")
                STACKS_24_LEADER=$TRUE
                STACKS_24_FOLLOWER=$TRUE
                STACKS_NAKA_LEADER=$TRUE
                STACKS_NAKA_FOLLOWER=$TRUE
                START=$TRUE
            ;;
            "--signer")
                STACKS_SIGNER=$TRUE
            ;;
            "--node")
                shift
                case "$1" in
                    "24-leader")
                        STACKS_24_LEADER=$TRUE
                        START=$TRUE
                    ;;
                    "24-follower")
                        STACKS_24_FOLLOWER=$TRUE
                        START=$TRUE
                    ;;
                    "naka-leader")
                        STACKS_NAKA_LEADER=$TRUE
                        START=$TRUE
                    ;;
                    "naka-follower")
                        STACKS_NAKA_FOLLOWER=$TRUE
                        START=$TRUE
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

    if [ $START -eq $FALSE ]; then
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

    if [ $STACKS_SIGNER -eq $TRUE ]; then
        echo "Starting the signer node..."
        docker compose up stacks-signer
    fi

    poll_containers
}

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

    # TODO: Move this later
    poll_containers
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

