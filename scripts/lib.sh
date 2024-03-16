#! /usr/bin/env bash

# shellcheck source=constants.sh
. "$PWD/scripts/constants.sh"

# Trims leading and trailing double quotes from a string.
#
# @param $1: The input string (required)
trim_quotes() {
  echo "$1" | tr -d '"'
}

# Pads a string to a specific length, left-aligned, with spaces.
#
# @param $1: The desired column width (required)
# @param $2: The input string (required)
pad() {
  local -i length width pad_right
  local -- str

  width=${1:?} # Mandatory column width
  str=${2:?} # Mandatory input string
  length=$( echo -e -n "$str" | sed "s/$(echo -e -n "\e")[^m]*m//g" | wc -c )
  pad_right=$((width - length))

  printf '%s%*s' "${str}" $pad_right ''
}

# Reads environment variables from the specified file and exports them.
# Defaults to '.env' if no file is specified.
#
# @param $1: The file path (optional, default: '.env')
read_env() {
  local filePath="${1:-.env}"
  local CLEANED_LINE

  if [ ! -f "$filePath" ]; then
    echo "missing ${filePath}"
    exit 1
  fi

  while read -r LINE; do
    # Remove leading and trailing whitespaces, carriage return and double quotes.
    CLEANED_LINE=$(echo "$LINE" | awk '{$1=$1};1' | tr -d '\r' | tr -d '"')

    # If we're not dealing with a comment and the line contains an equal sign
    # then export the variable. This also gets rid of empty lines.
    if [[ $CLEANED_LINE != '#'* ]] && [[ $CLEANED_LINE == *'='* ]]; then
      # shellcheck disable=SC2163
      export "$CLEANED_LINE"
    fi
  done < "$filePath"
}

log() {
  if [ -z "$REGTEST_ENV_ID" ]; then
    return
  fi

  local -r message="${1:?}"
  local -i pad="${2:-0}"
  local -r timestamp=$(date +"%Y-%m-%d %T")

  printf "[%s] %s" "$timestamp" "$message" >> "$ENV_LOG_FILE"

  if [ "$pad" -gt 0 ]; then
    pad $pad "$message"
  else
    printf "%s" "$message"
  fi
}

log_line() {
  log "$1\n"
}

is_valid_stacks_epoch() {
  local -r epoch="${1:?}"
  epochs=("1.0" "2.0" "2.05" "2.1" "2.2" "2.3" "2.4" "2.5" "3.0")
  for valid_epoch in "${epochs[@]}"; do
    if [ "$epoch" == "$valid_epoch" ]; then
      return 0
    fi
  done
  return 1
}