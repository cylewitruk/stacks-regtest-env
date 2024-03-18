#! /usr/bin/env bash

print_manifest_help() {
help=$(cat << EOF
Commands for working with environment manifests.

${BOLD}Available Commands:${NC}
  new                       Create a new environment manifest.
  list                      List all available environment manifests.
  rm                        Delete an environment manifest.
  help, -h, --help          Print this help message
EOF
)
  echo -e "$help"
}

exec_manifest() {
  case $1 in
    new)
      shift
      exec_new_manifest "$@"
      ;;
    list)
      exec_list_manifests
      ;;
    rm)
      shift
      exec_rm_manifest "$@"
      ;;
    *)
      print_manifest_help
      ;;
  esac
}

exec_list_manifests() {
  readarray manifest_names < <(dasel select -f ~/.stacks-regtest/regtestrc.yml -s ".environments.[*].name" -m)
  echo "${manifest_names[@]}"
}