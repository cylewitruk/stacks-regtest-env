#! /usr/bin/env bash
# shellcheck source-path=SCRIPTDIR/scripts
# shellcheck disable=SC2059

# Set the PWD for script imports to know where they're at.
PWD="$(pwd)"

export USER_ID
USER_ID="$(id -u)"
export USER_NAME
USER_NAME="$(id -un)"

export GROUP_ID
GROUP_ID="$(id -g)"
export GROUP_NAME
GROUP_NAME="$(id -gn)"

# Imports
. ./scripts/constants.sh
. ./scripts/docker.sh
. ./scripts/lib.sh
. ./scripts/cmd.start.sh
. ./scripts/cmd.ls.sh
. ./scripts/cmd.clean.sh

# Load build-time environment variables
read_env .env

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

# Main entry point for the program
main() {
    # Set the current environment id, if available. This checks for the
    # existence of an 'environment' container and sets the REGTEST_ENV_ID
    # variable if found.
    get_current_environment_id

    # If there's no environment, let the user know that some commands will be
    # unavailable.
    if [ -z "$REGTEST_ENV_ID" ]; then
        printf "${GRAY}Note: No active environment; some commands are unavailable.${NC}\n\n"
    else 
        printf "${GRAY}Regtest environment: $REGTEST_ENV_ID${NC}\n\n"
    fi

    # Parse the command line arguments
    case "$1" in 
        "--help") 
            print_help ;;
        "start")
            shift
            exec_start "$@"
        ;;
        "build")
            docker compose build ;;
        "clean")
            exec_clean
        ;;
        "stop")
            docker compose down --remove-orphans --timeout 0
            unset REGTEST_ENV_ID
        ;;
        "ls") 
            exec_ls ;;
        "test") 
            test ;;
        *)
            printf "${RED}ERROR:${NC} Unknown command '$1'.\n"
            print_help ;;
    esac
}

# ==============================================================================
# MAIN PROGRAM ENTRY POINT
# ==============================================================================

# We hide this way down here so that our order of declarations 
# above don't matter =)
main "$@"

