#! /usr/bin/env bash
# shellcheck disable=SC2059

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

# Logs a message to the console and to the environment log file, if any.
#
# @param $1: The message to log (required)
# @param $2: The padding value (optional, default: 0)
log() {
  local message="${1:?}"
  local -i pad="${2:-0}"
  local -r timestamp=$(date +"%Y-%m-%d %T")

  # If a padding value is provided, pad the message
  if [ "$pad" -gt 0 ]; then
    message=$(pad $pad "$message")
  fi

  # If the REGTEST_ENV_ID environment variable is set, log to the environment 
  # log file.
  if [ -n "$REGTEST_ENV_ID" ]; then
    printf "[%s] %s" "$timestamp" "$message" >> "$ENV_LOG_FILE"
  fi

  printf "%s" "$message"
}

log_line() {
  log "$1\n"
}

# Asserts that the specified epoch is valid.
#
# @param $1: The epoch as a string (i.e. '2.4') (required)
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

# Asserts that the specified contract name is valid.
#
# @param $1: The contract name (required)
is_valid_contract_name() {
  [[ "$1" =~ ^([a-zA-Z](([a-zA-Z0-9]|[-_])){1,127})$ ]]
}

# Asserts that the specified Clarity name is valid.
#
# @param $1: The Clarity name (required)
is_valid_clarity_name() {
  [[ "$1" =~ ^([a-zA-Z]([a-zA-Z0-9]|[-_!?+<>=/*])*$){1,127}|([-+=/*]){1,127}|([<>]=?){1,127} ]]
}

# Asserts that the specified option is set and has a value.
# The only difference between this function and `assert_arg` is the error message.
#
# @param $1: The option name (required)
# @param $2: The option value (optional)
assert_opt() {
  local -r option="${1:?}"
  local -r value="${2:-}"

  if [ -z "$value" ]; then
    printf "${RED}ERROR:${NC} The ${BOLD}$option${NC} option is required.\n"
    return 1
  fi
  return 0
}

# Asserts that the specified argument is set and has a value.
# The only difference between this function and `assert_opt` is the error message.
#
# @param $1: The argument name (required)
# @param $2: The argument value (optional)
assert_arg() {
  local -r arg="${1:?}"
  local -r value=${2:-}

  if [ -z "$value" ]; then
    printf "${RED}ERROR:${NC} The ${BOLD}$arg${NC} argument is required.\n"
    return 1
  fi
  return 0
}

eq() {
  [ "$1" -eq "$2" ]
}