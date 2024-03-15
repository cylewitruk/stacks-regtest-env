#! /usr/bin/env bash

# shellcheck disable=SC2034

# Encoding
LC_CTYPE=en_US.UTF-8

# Colors
GRAY='\e[0;90m'        # Gray
BLACK='\e[0;30m'        # Black
RED='\e[0;31m'          # Red
GREEN='\e[0;32m'        # Green
YELLOW='\e[0;33m'       # Yellow
BLUE='\e[0;34m'         # Blue
PURPLE='\e[0;35m'       # Purple
CYAN='\e[0;36m'         # Cyan
WHITE='\e[0;37m'        # White
NC='\e[0m' # No Color
BOLD='\e[1m' # Bold
ITALIC='\e[3m' # Italic

# Other constants
NULL='null'
TRUE=1
FALSE=0

# Stacks labels (local.stacks.*) - used to label docker containers
ROLE_LABEL='role'
ENV_ID_LABEL='environment_id'
NODE_VERSION_LABEL='node_version'
LEADER_LABEL='leader'

EPOCH_1_0='1.0'
EPOCH_2_0='2.0'
EPOCH_2_05='2.05'
EPOCH_2_1='2.1'
EPOCH_2_2='2.2'
EPOCH_2_3='2.3'
EPOCH_2_4='2.4'
EPOCH_2_5='2.5'
EPOCH_3_0='3.0'