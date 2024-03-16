#! /usr/bin/env bash

print_contract_call_help() {
  cat << EOF
Usage: ./regtest contract-call CONTRACT FUNCTION [OPTIONS]
* Call a public or read-only FUNCTION on CONTRACT.
* CONTRACT must be the fully-qualified name of the contract, including the
  contract principal.

Example: ./regtest contract-call \\
  ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.counter \\
  increment \\
  --sender STSTW15D618BSZQB85R058DS46THH86YQQY6XCB7 \\
  --arg 'u1'

Required Options:
  -s, --sender string       The Stacks address of the sender. This is the
                              address that will pay for the contract call.

Additional Options:
  --sponsor string          Optionally specifies the Stacks address of the
                              sponsor for this transaction.
  -a, --arg string          Provides an argument to the function. This option
                              can be used multiple times to provide multiple
                              arguments. The arguments will be passed to the
                              function in the order they are provided.
  --cost int                Optionally specifies the cost of the transaction.
  --help                    Print this help message.
EOF
}

exec_contract_call() {
  while test $# != 0; do
    case "$1" in 
      "--help")
        print_contract_call_help
        exit 0
      ;;
      *) 
        print_contract_call_help
        exit 0
      ;;
    esac
  shift
  done
}