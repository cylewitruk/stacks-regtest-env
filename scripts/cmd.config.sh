#! /usr/bin/env bash

print_config_help() {
help=$(cat << EOF
Commands for reading or altering the regtest environment configuration.

${BOLD}Available Commands:${NC}
  get                       Get the value of a configuration option.
  set                       Set the value of a configuration option.
  list                      List all configuration options and their values.
  help, -h, --help          Print this help message
EOF
)
  echo -e "$help"
}

exec_config() {
  case $1 in
    get)
      shift
      exec_get_config "$@"
      ;;
    set)
      shift
      exec_set_config "$@"
      ;;
    list)
      exec_list_config
      ;;
    *)
      print_config_help
      ;;
  esac
}