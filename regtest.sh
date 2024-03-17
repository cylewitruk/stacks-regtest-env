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
  help=$(cat << EOF
Usage: 
  ./regtest ${BOLD}COMMAND${NC} [OPTIONS]

${BOLD}Available Commands:${NC}
  build                     Build the regtest environment.
  start                     Start the regtest environment.
  ls                        List all running services for the current
                              environment.
  clean                     Clean regtest data from disk. If there is an active
                              environment, it will be skipped.
  epochs                    Print a list of available epochs for the regtest
                              environment.

${BOLD}Environment Commands:${NC}
${GRAY}${ITALIC}These commands require a running environment.${NC}
  stop                      Stop the currently running environment.
  contract-deploy           Deploy a contract to the active environment.
  contract-call             Call a public or read-only function on a contract
                              in the active environment.

${BOLD}Other:${NC}
  help, -h, --help          Print this help message
EOF
)

  printf "$help\n\n"
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
    "--help"|"-h"|"help") 
      print_help ;;
    "start")
      shift # Shift the command off the argument list
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
      shift # Shift the command off the argument list
      exec_contract_deploy "$@" ;;
    "contract-call")
      shift # Shift the command off the argument list
      exec_contract_call "$@" ;;
    "epochs")
      echo "The following epochs are available to be used for '--epoch' options:"
      echo "‣ 1.0"
      echo "‣ 2.0"
      echo "‣ 2.05"
      echo "‣ 2.1"
      echo "‣ 2.2"
      echo "‣ 2.3"
      echo "‣ 2.4"
      echo "‣ 2.5"
      echo "‣ 3.0"
      echo
      exit 0
      ;;
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

