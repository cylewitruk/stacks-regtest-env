#! /usr/bin/env bash

#. ./regtest.sh "load-only"

tmp() {
  [ $# -ge 1 ] && [ -f "$1" ] && input="$1" || input="-"
  tmp=$(cat "$input")
  echo "$tmp"
}

tmp "$@"