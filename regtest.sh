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

# Imports (general)
. ./scripts/constants.sh
. ./scripts/docker.sh
. ./scripts/lib.sh
. ./scripts/monitor.sh

# Imports (commands)
. ./scripts/cmd.start.sh
. ./scripts/cmd.ls.sh
. ./scripts/cmd.clean.sh
. ./scripts/cmd.stop.sh
. ./scripts/cmd.contract-deploy.sh
. ./scripts/cmd.contract-call.sh

# Load build-time environment variables
read_env .env

# Prints the help message for the main program
print_help() {
  cat << EOF
Usage: ./regtest.sh COMMAND [OPTIONS]

Available Commands:
  build                     Build the regtest environment.
  start                     Start the regtest environment.
  stop                      Stop the regtest environment.
  ls                        List all running services for the current 
                              environment.
  clean                     Clean regtest data from './environments'.
  contract-deploy           Deploy a contract to the environment.
  contract-call             Call a public or read-only function on a contract
                              in the regtest environment.

Available Options:
  --help          Print this help message
EOF
}

# Main entry point for the program
main() {
  if [ "$#" -eq 0 ]; then
    printf "${RED}ERROR:${NC} No command provided.\n"
    print_help
    exit 0
  fi
  # Set the current environment id, if available. This checks for the
  # existence of an 'environment' container and sets the REGTEST_ENV_ID
  # variable if found.
  get_current_environment_id

  # If there's no environment, let the user know that some commands will be
  # unavailable.
  if [ -z "$REGTEST_ENV_ID" ]; then
    printf "${GRAY}NOTE: No active environment; some commands are unavailable.${NC}\n\n"
  else 
    printf "${GRAY}Environment ID: $REGTEST_ENV_ID${NC}\n\n"
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
      exec_stop
    ;;
    "ls") 
      exec_ls ;;
    "contract-deploy") 
      exec_contract_deploy "$@" ;;
    "contract-call")
      exec_contract_call "$@" ;;
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
if [ "$1" != "load-only" ]; then
  main "$@"
fi

