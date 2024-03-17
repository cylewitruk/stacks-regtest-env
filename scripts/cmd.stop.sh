#! /usr/bin/env bash
# shellcheck disable=SC2059

exec_stop() {
  if [ -z "$REGTEST_ENV_ID" ]; then
    printf "${RED}ERROR:${NC} No regtest environment is currently active.\n"
    exit 0
  fi

  monitor_pid_file="./environments/$REGTEST_ENV_ID/run/monitor.pid"

  echo "Stopping regtest environment"
  monitor_pid=$( cat "$monitor_pid_file" )
  pad 50 "‣ Stopping monitor (PID $monitor_pid)..."
  if [ -n "$monitor_pid" ]; then
    if ! kill -9 "$monitor_pid" > /dev/null 2>&1; then
      printf "[${RED}FAIL${NC}]\n"
    else
      printf "[${GREEN}OK${NC}]\n"
    fi
  else
    printf "[${YELLOW}SKIP${NC}]\n"
  fi

  pad 50 "‣ Stopping regtest environment..."
  if ! docker compose down --remove-orphans --timeout 0 > /dev/null 2>&1;
  then
    printf "[${RED}FAIL${NC}]\n"
    exit 1
  else 
    printf "[${GREEN}OK${NC}]\n"
  fi

  unset REGTEST_ENV_ID
  
  printf "\n${BOLD}To remove artifacts, run:${NC} ./regtest clean\n\n"
  printf "${BOLD}${GREEN}Success:${NC} Regtest environment has been stopped.\n\n"
}