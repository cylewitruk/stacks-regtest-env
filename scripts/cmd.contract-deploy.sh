#! /usr/bin/env bash
# shellcheck disable=SC2059

# Prints the help message for the contract-deploy command.
print_contract_deploy_help() {
  help=$(cat << EOF
Deploys a CONTRACT to the regtest environment with the given SOURCE code.
$(print_contract_name_help)
* SOURCE$ must be a either a path to a file containing the contract source code or
  '-' to read the contract source code from standard input.

$(print_contract_deploy_usage)

${BOLD}Examples:${NC}
  ${GRAY}${ITALIC}# Get SOURCE from a file${NC}
  ./regtest contract-deploy counter
    --sender ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM
    --epoch '2.4'
    /home/foo/counter.clar

  ${GRAY}${ITALIC}# Get SOURCE from stdin${NC}
  cat /home/foo/counter.clar | ./regtest contract-deploy counter
    --sender ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM
    --epoch '2.4'

${BOLD}Required Options:${NC}
  -s, --sender              The Stacks address of the sender. This is the
                              address that will deploy the contract.
  -e, --epoch string          The Stacks blockchain epoch to use for the
                              deployment. This must be a valid Stacks epoch
                              version number, such as '2.0', '2.05', '2.4', etc.

${BOLD}Additional Options:${NC}
  -d, --deployment          Optionally overrides the Clarinet deployment name,
                              which defaults to <contract-name>-deployment.
  -n, --node                Optionally specifies the Stacks node to use for the
                              deployment. If not specified, a random node will
                              be selected.
  --cost                    Optionally specifies the cost of the transaction.
  --block-only              Optionally specifies that the Stacks transaction may
                              only be included in a block and not a microblock.
  --microblock-only         Optionally specifies that the Stacks transaction may
                              only be included in a microblock and not a block.

${BOLD}Other:${NC}
  -h, --help                Print this help message.
EOF
)

  printf "$help\n\n"
}

print_contract_deploy_usage() {
  printf "${BOLD}Usage:${NC}\n"
  printf "  1) ./regtest ${BOLD}contract-deploy CONTRACT${NC} [OPTIONS] ${BOLD}SOURCE${NC}\n"
  printf "  2) cat <${BOLD}SOURCE${NC} file> | ./regtest ${BOLD}contract-deploy CONTRACT${NC} [OPTIONS]\n"
}

# Prints a subset of the help text pertaining to Clarity contract names.
print_contract_name_help() {
  printf "* ${BOLD}CONTRACT${NC} must be a valid Clarity contract name:\n"
  printf "  ‣ Must be between 1 and 127 characters long.\n"
  printf "  ‣ May only contain letters, numbers, hyphens, and underscores.\n"
  printf "  ‣ Must start with a letter.\n"
  printf "  ${GRAY}Regex: ^([a-zA-Z](([a-zA-Z0-9]|[-_])){1,127})\$${NC}\n"

}

# Entry point for the contract-deploy command.
exec_contract_deploy() {

  if [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
    print_contract_deploy_help
    exit 0
  fi

  local -r contract_name=$1
  local -r default_cost=2000
  local -r default_deployment_name="${contract}-deployment"

  if [ -z "$contract_name" ]; then
    printf "${RED}ERROR:${NC} The ${BOLD}CONTRACT${NC} argument is missing.\n\n"
    print_contract_deploy_usage
    echo
    print_contract_name_help
    exit 1
  fi

  if ! is_valid_contract_name "$contract_name"; then
    printf "${RED}ERROR:${NC} Invalid contract name: '$contract_name'\n"
    print_contract_name_help
    exit 1
  fi

  echo "Contract name: $contract_name"

  shift # Shift the contract name off the argument list
  while test $# != 0; do
    case "$1" in 
      "--help"|"-h")
        print_contract_deploy_help
        exit 0
      ;;
      "--epoch"|"-e")
        shift
        if [ -z "$1" ]; then
          printf "${RED}ERROR:${NC} The ${BOLD}--epoch${NC} option requires a value.\n"
          exit 1
        fi
        if ! is_valid_stacks_epoch "$1"; then
          printf "${RED}ERROR:${NC} Invalid Stacks blockchain epoch: $1\n"
          exit 1
        fi
        local -r epoch=$1
      ;;
      "--sender"|"-s")
        shift
        if [ -z "$1" ]; then
          printf "${RED}ERROR:${NC} The ${BOLD}--sender${NC} option requires a value.\n"
          exit 1
        fi
        local -r sender=$1
      ;;
      *)
        break ;;
    esac
  shift
  done

  # Assert that the epoch flag has been set.
  if ! assert_opt "--epoch" "$epoch"; then
    exit 1
  fi

  # Assert that the sender flag has been set.
  if ! assert_opt "--sender" "$sender"; then
    exit 1
  fi

  echo -e "Installing contract ${CYAN}$contract_name${NC} with epoch ${CYAN}$epoch${NC} and sender ${CYAN}$sender${NC} from source ${CYAN}$1${NC}.\n"

  # Set the input variable to either the file path or '-' to read from stdin.
  if [ $# -ge 1 ] && [ -f "$1" ]; then
    input="$1"
  elif [ $# -ge 1 ] && [ "$1" = "-" ]; then
    input="-"
  elif [ $# -ge 1 ] && [ ! -f "$1" ]; then
    printf "${RED}ERROR:${NC} The specified source file was not found.\n\n"
    print_contract_deploy_usage
    exit 1
  elif [ $# -eq 0 ] && [ ! -t 0 ]; then
    input="-"
  elif [ $# -eq 0 ] && [ -t 0 ]; then
    printf "${RED}ERROR:${NC} Cannot read stdin from a terminal; please pipe the contract source to \n"
    printf "this command.\n\n"
    print_contract_deploy_usage
    exit 1
  else
    printf "${RED}ERROR:${NC} No contract source provided.\n\n"
    print_contract_deploy_usage
    exit 1
  fi

  declare -r contract_src=$(cat "$input")
  if [ -z "$contract_src" ]; then
    printf "${RED}ERROR:${NC} Contract source input was empty.\n\n"
    print_contract_deploy_usage
    exit 1
  fi

  echo "$contract_src"
}