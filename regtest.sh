#!/bin/sh

TRUE=1
FALSE=0

export USER_ID
USER_ID="$(id -u)"
USER_NAME="$(id -un)"

export GROUP_ID
GROUP_ID="$(id -g)"
GROUP_NAME="$(id -gn)"

export REGTEST_ENV_ID
REGTEST_ENV_ID="$(date +%Y%m%d%H%M%S)"

# Variables to control which nodes to start
stacks_24_leader=$FALSE
stacks_24_follower=$FALSE
stacks_naka_leader=$FALSE
stacks_naka_follower=$FALSE
stacks_signer=$FALSE
start=$FALSE

# The main entry point for the program
program() {
    while test $# != 0; do
        case "$1" in 
            "start")
                shift
                exec_start "$@"
                exit 0
            ;;
            "build")
                docker compose build
            ;;
            "clean")
                rm -rf ./environments/*
                exit 0
            ;;
            "stop")
                docker compose down
                exit 0
            ;;
            "--help")
                print_help
                exit 0
            ;;
        esac
        shift
    done
}

# The entry point for the start command
exec_start() {
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
    sh -c "docker compose up $services"

    if [ $stacks_signer -eq $TRUE ]; then
        echo "Starting the signer node..."
        docker compose up stacks-signer
    fi
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

# Prints the help message for the main program
print_help() {
    cat << EOF
Usage: ./regtest.sh COMMAND [OPTIONS]

Available Commands:
    start           Start the regtest environment
    build           Build the regtest environment

Available Options:
    --help          Print this help message
EOF
}

# Prints the help message for the start command
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

# Executes the main program
program "$@"