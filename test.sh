#! /usr/bin/env bash

. ./regtest.sh "load-only"


if is_valid_stacks_epoch 'asd'; then
  echo "Valid"
else
  echo "Invalid"
fi