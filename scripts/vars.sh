#! /usr/bin/env bash

# shellcheck disable=SC2034

export USER_ID
USER_ID="$(id -u)"
export USER_NAME
USER_NAME="$(id -un)"

export GROUP_ID
GROUP_ID="$(id -g)"
export GROUP_NAME
GROUP_NAME="$(id -gn)"

# Variables to control which nodes to start
STACKS_24_LEADER=$FALSE
STACKS_24_FOLLOWER=$FALSE
STACKS_NAKA_LEADER=$FALSE
STACKS_NAKA_FOLLOWER=$FALSE
STACKS_SIGNER=$FALSE
START=$FALSE