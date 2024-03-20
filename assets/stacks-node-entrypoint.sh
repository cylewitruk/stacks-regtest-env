#!/bin/bash

echo "Preparing to start Stacks regtest environment..."

# Include our binaries in the PATH
export PATH="$PATH:/stacks/bin/"
echo "Executing at: $BASH_SOURCE"
PWD=$(dirname "$BASH_SOURCE")

#chmod -R u+rw /stacks
mkdir -p \
  /stacks/data \
  /stacks/conf \
  /stacks/inbox \
  /stacks/outbox \
  /stacks/run

touch \
  /stacks/run/host \
  /stacks/run/container

# Load helper functions
# shellcheck source=stacks-node-entrypoint-lib.sh
. "${PWD}"/stacks-node-entrypoint-lib.sh

sleep 1.5

# echo "Copying configuration files..." >> "$NODE_LOG"
# echo "Leader: $LEADER" >> "$NODE_LOG"
# if [ "$LEADER" = "true" ]; then
#   echo "Moving leader config to stacks-node.toml" >> "$NODE_LOG"
#   cp /stacks/tmp/stacks-leader.toml /stacks/conf/stacks-node.toml >> "$NODE_LOG"
#   ls /stacks/conf >> "$NODE_LOG"
# else
#   echo "Moving follower config to stacks-node.toml" >> "$NODE_LOG"
#   cp /stacks/tmp/stacks-follower.toml /stacks/conf/stacks-node.toml >> "$NODE_LOG"
# fi

# echo "Copying configuration files..." >> "$NODE_LOG"
cp /stacks/tmp/stacks-node.toml /stacks/conf/stacks-node.toml >> "$NODE_LOG"

# Print configuration details
print_config

# Ensure that the node version is set to a valid value
validate_node_version

# Wait for the Bitcoin RPC server to start
wait_for_bitcoin_init

# If we're a leader (miner) node, generate a new keychain and import it into
# the Bitcoin node and update the Stacks miner config with the new keychain.
# Otherwise, just start the Stacks node with the follower config.
configure_node

# Start the run-loop
run