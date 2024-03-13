#!/bin/sh

echo "Preparing to start Stacks regtest environment..."
sleep 3

# Include our binaries in the PATH
export PATH="$PATH:/stacks/bin/"

# Load helper functions
. stacks-funcs.sh

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

btc_block_height=$( bitcoin-cli getblockcount )
last_btc_block_height=$btc_block_height
echo "₿ Bitcoin block height: $btc_block_height"

# Create node data directory and log files
mkdir -p /stacks/logs /stacks/data
touch /stacks/logs/stacks-2.4.log
touch /stacks/logs/stacks-nakamoto.log
touch /stacks/logs/stacks-signer.log

# Main loop
while :
do
  # Check if we're in a new Bitcoin block
  if [ "$last_btc_block_height" -ne "$btc_block_height" ]
  then
    btc_block_height=$last_btc_block_height
    echo "₿ New Bitcoin block found: $btc_block_height"
    adjust_epoch "$btc_block_height"
  fi

  # If the node is not running, start it
  if [ -z "$running" ]
  then
    start_node "$NODE_VERSION"
  fi

  if [ "$running" = "2.4-leader" ] && [ "$btc_block_height" -ge "$STACKS_2_4_LEADER_NODE_UPGRADE_HEIGHT" ]
  then
    echo "2.4 leader node upgrade height reached 🚩 (burnchain block $STACKS_2_4_LEADER_NODE_UPGRADE_HEIGHT)"
    stop_node
    enable_debug
    start_node "nakamoto"
  fi
  
  sleep 1

  if [ "$(is_node_process_alive)" -ne 1 ]; then
    echo "🔥 Detected that the node process is not running, dumping log tail..."
    dump_logs
    echo "🔥 End of log dump -- exiting"
    exit 1
  fi
  
  logrotate "$running"
  last_btc_block_height=$( bitcoin-cli getblockcount )
done