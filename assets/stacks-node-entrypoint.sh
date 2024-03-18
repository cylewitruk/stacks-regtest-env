#!/bin/bash

echo "Preparing to start Stacks regtest environment..."

# Include our binaries in the PATH
export PATH="$PATH:/stacks/bin/"

#chmod -R u+rw /stacks
mkdir -p \
  /stacks/inbox \
  /stacks/outbox \
  /stacks/run \
  /bitcoin/data \
  /bitcoin/logs

touch \
  /stacks/run/host \
  /stacks/run/container

chmod +x /stacks/bin/*

# Load helper functions
# shellcheck source=stacks-node-entrypoint-lib.sh
. .stacks-node-entrypoint-lib.sh

sleep 1.5

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