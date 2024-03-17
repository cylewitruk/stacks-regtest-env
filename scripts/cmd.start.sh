#! /usr/bin/env bash
# shellcheck disable=SC2059 # Because we use colors with `printf`

# shellcheck source=docker.sh
. "$PWD/scripts/docker.sh"
#. "$PWD/scripts/monitor.sh"

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
  help=$(cat << EOF
Starts the regtest environment with the specified configuration.
* At least one node (-n|--node) must be specified to start the environment.

${BOLD}Usage:${NC}
   ./regtest.sh ${BOLD}start${NC} [OPTIONS]

${BOLD}Examples:${NC}
   ${GRAY}${ITALIC}# Start all nodes${NC}
   ./regtest start --all-nodes

   ${GRAY}${ITALIC}# Start the 24 leader and Naka follower nodes${NC}
   ./regtest start --node 24L --node NF

   ${GRAY}${ITALIC}# Start the 24 leader and 2 signer nodes${NC}
   ./regtest start --node 24-leader --signers 2

   ${GRAY}${ITALIC}# Start all nodes without installing default contracts${NC}
   ./regtest start --all-nodes --no-default-contracts

${BOLD}Available Options:${NC}
  -a, --all-nodes           Start all nodes.
  -s, --signers int         Optionally start the specified number of
                              signer nodes. This option may only be used once.
  -n, --node <node>         Start a specific node. This option may be
                              used multiple times to start multiple nodes,
                              i.e. --node 24-leader --node naka-leader.
                              May not be used in combination with --all-nodes.
                              The following node names are valid:
                                - 24-leader, 24L
                                - 24-follower, 24F
                                - naka-leader, NL
                                - naka-follower, NF
  --no-default-contracts    Does not install any default contracts into the
                              environment.
  -h, --help                Print this help message.
EOF
)

  printf "$help\n\n"
}

# Entry point for the start command.
exec_start() {
  while test $# != 0; do
    case "$1" in 
      "--help"|"-h")
        print_start_help
        exit 0
      ;;
      "--all-nodes"|"-a")
        STACKS_24_LEADER=$TRUE
        STACKS_24_FOLLOWER=$TRUE
        STACKS_NAKA_LEADER=$TRUE
        STACKS_NAKA_FOLLOWER=$TRUE
        START=$TRUE
      ;;
      "--signer"|"-s")
        STACKS_SIGNER=$TRUE
      ;;
      "--node"|"-n")
        shift
        case "$1" in
          "24-leader"|"24L")
            STACKS_24_LEADER=$TRUE
            START=$TRUE
          ;;
          "24-follower"|"24F")
            STACKS_24_FOLLOWER=$TRUE
            START=$TRUE
          ;;
          "naka-leader"|"NL")
            STACKS_NAKA_LEADER=$TRUE
            START=$TRUE
          ;;
          "naka-follower"|"NF")
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

  ENV_LOGS_DIR="./environments/$REGTEST_ENV_ID/logs"
  ENV_RUN_DIR="./environments/$REGTEST_ENV_ID/run"
  ENV_LOG_FILE="$ENV_LOGS_DIR/regtest.log"
  mkdir -p "$ENV_LOGS_DIR" "$ENV_RUN_DIR"

  services="$(get_services_string)"

  echo "----------------------------------------"
  echo "Preparing to start Stacks regtest environment"
  echo "‣ User: $USER_NAME ($USER_ID) : $GROUP_NAME ($GROUP_ID)"
  echo "‣ Environment ID: $REGTEST_ENV_ID"
  echo "‣ Path: $PWD/environments/$REGTEST_ENV_ID/"
  echo "‣ Services: $services"
  echo "----------------------------------------"

  echo "Starting environment..."
  pad 50 "‣ Building services"
  if sh -c "docker compose build $services" >> "$ENV_LOG_FILE" 2>&1; then
    printf "[${GREEN}OK${NC}]\n"
  else
    printf "[${RED}FAIL${NC}]\n"
    exit 1
  fi

  # Start the internal 'environment' service, which is used to store
  # environment-related information. This service should be the first started
  # and last stopped for an environment.
  pad 50 "‣ Starting the 'environment' service..."
  if docker compose up -d environment --build >> "$ENV_LOG_FILE" 2>&1; then
    printf "[${GREEN}OK${NC}]\n"
  else
    printf "[${RED}FAIL${NC}]\n"
    exit 1
  fi

  pad 50 "‣ Starting the remaining services..."
  if sh -c "docker compose up -d $services" >> "$ENV_LOG_FILE" 2>&1; then
    printf "[${GREEN}OK${NC}]\n"
  else
    printf "[${RED}FAIL${NC}]\n"
    exit 1
  fi

  # Start signer node(s) if requested.
  if [ "$STACKS_SIGNER" -eq "$TRUE" ]; then
    echo "Starting the signer node..."
    docker compose up stacks-signer
  fi

  # Start the monitor script in the background, and store the PID in a file.
  pad 50 "‣ Starting the background monitor..."
  if monitor >> "$ENV_LOG_FILE" &
  then
    local -i monitor_pid=$!
    echo "$monitor_pid" > "$ENV_RUN_DIR/monitor.pid"
    printf "[${GREEN}OK${NC}] ${GRAY} pid:$monitor_pid${NC}\n\n"
  else
    printf "[${RED}FAIL${NC}]\n"
    exit 1
  fi

  sleep 1
  printf "🚀 Environment launched!\n\n"

  exec_ls

  printf "\n${BOLD}To stop the environment, run:${NC} ./regtest stop\n\n"
  printf "${BOLD}${GREEN}Success:${NC} Regtest environment has been started.\n\n"
}