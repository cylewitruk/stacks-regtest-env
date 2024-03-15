#! /usr/bin/env bash
# shellcheck disable=SC2059 # Because we use colors with `printf`

# shellcheck source=docker.sh
. "$PWD/scripts/docker.sh"

# Variables to control which nodes to start
STACKS_24_LEADER=$FALSE
STACKS_24_FOLLOWER=$FALSE
STACKS_NAKA_LEADER=$FALSE
STACKS_NAKA_FOLLOWER=$FALSE
STACKS_SIGNER=$FALSE
START=$FALSE
DEFAULT_CONTRACTS=$TRUE

# Prints the help message for the start command.
print_start_help() {
  cat << EOF
Usage: ./regtest.sh start [OPTIONS]

Available Options:
  --all-nodes               Start all nodes.
  --signer                  Start the signer node.
  --node <node>             Start a specific node [24-leader, 24-follower, 
                             naka-leader, naka-follower].
  --help                    Print this help message.
  --no-default-contracts    Does not install any default contracts into the
                             environment.
EOF
}

# Entry point for the start command.
exec_start() {
  while test $# != 0; do
    case "$1" in 
      "--help")
        print_start_help
        exit 0
      ;;
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
      "--no-default-contracts")
        DEFAULT_CONTRACTS=$FALSE
      ;;
      *) 
        print_start_help
        exit 0
      ;;
    esac
  shift
  done

  if [ "$START" -eq "$FALSE" ]; then
    printf "${RED}ERROR:${NC} No nodes specified to start.\n"
    print_start_help
    exit 0
  fi

  if [ -n "$REGTEST_ENV_ID" ]; then
    printf "${RED}ERROR:${NC} An environment is already running - please stop it before starting a new one.\n"
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

  if [ "$STACKS_SIGNER" -eq "$TRUE" ]; then
    echo "Starting the signer node..."
    docker compose up stacks-signer
  fi

  poll_containers
}