#! /usr/bin/env bash

PWD="$(pwd)"

. ./scripts/constants.sh
. ./scripts/docker.sh
. ./scripts/cmd.start.sh
. ./scripts/cmd.ls.sh

REGTEST_ENV_ID="asd3a67sd5a2sd"

get_random_stacks_node_container_id "$FALSE"