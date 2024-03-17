#! /usr/bin/env bash
# shellcheck disable=SC2034

declare -x \
  USAGE_MAIN \
  USAGE_START

strip_ansi_colors() {
  echo "$1" | sed -r "s/\x1B\[([0-9]{1,3}(;[0-9]{1,3})*)?[mGK]//g"
}

build_readme() {
  USAGE_MAIN="$( strip_ansi_colors "$( ./regtest help  )" | sed 1,2d )"
  USAGE_START="$( strip_ansi_colors "$( ./regtest start --help )" | sed 1,2d )"

  envsubst < "README.tpl.md" > "README.md"
}

build_readme