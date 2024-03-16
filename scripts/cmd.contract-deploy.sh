#! /usr/bin/env bash
# shellcheck disable=SC2059

# Prints the help message for the contract-deploy command.
print_contract_deploy_help() {
  cat << EOF
Usage: ./regtest.sh contract-deploy CONTRACT [OPTIONS] SOURCE
* Deploys a CONTRACT to the regtest environment with the given SOURCE code.
  CONTRACT must be a valid Clarity name.
* SOURCE must be a either a path to a file containing the contract source code or
  '-' to read the contract source code from standard input.

Example: ./regtest.sh contract-deploy counter \\
  --sender ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM \\
  --epoch '2.4' \\
  --cost 1000 \\
  counter.clar

Required Options:
  -s, --sender              The Stacks address of the sender. This is the
                              address that will deploy the contract.
  -e, --epoch string          The Stacks blockchain epoch to use for the
                              deployment. This must be a valid Stacks epoch
                              version number, such as '2.0', '2.05', '2.4', etc.

Additional Options:
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
  --help                    Print this help message.
EOF
}

exec_contract_deploy() {
  while test $# != 0; do
    case "$1" in 
      "--help")
        print_contract_deploy_help
        exit 0
      ;;
      "--epoch")
        shift
        if ! is_valid_stacks_epoch "$1"; then
          printf "${RED}ERROR:${NC} Invalid Stacks blockchain epoch: $1\n"
          exit 1
        fi
      ;;
      *) 
        print_contract_deploy_help
        exit 0
      ;;
    esac
  shift
  done
}