#!/bin/bash

DOCKER_ID="$( hostname )"
HOSTNAME="$( grep "$DOCKER_ID" /etc/hosts | sed 's/\s/\n/g' | tail -1 )"

# Define common variables
EPOCH_1_0=1
EPOCH_2_0=2
EPOCH_2_05=3
EPOCH_2_1=4
EPOCH_2_2=5
EPOCH_2_3=6
EPOCH_2_4=7
EPOCH_2_5=8
EPOCH_3_0=9

NODE_LOG="/stacks/logs/stacks-node-$HOSTNAME.log"
SIGNER_LOG="/stacks/logs/stacks-signer-$HOSTNAME.log"
NODE_INDEX_DB="/stacks/data/krypton/chainstate/vm/index.sqlite"

CURRENT_EPOCH=$EPOCH_1_0

BITCOIN_BLOCK_HEIGHT=-1
STACKS_BLOCK_HEIGHT=-1

TRUE=1
FALSE=0

_2_4_EPOCHS_WRITTEN=$FALSE
_NAKA_EPOCHS_WRITTEN=$FALSE
_NAKA_DB_MIGRATIONS_RUN=$FALSE
_NODE_CONFIGURED=$FALSE

# General debug configuration
export RUST_BACKTRACE=0
export RUST_LOG=info
export BLOCKSTACK_DEBUG=0

# Enables debug/trace logging for Stacks binaries
enable_debug() {
  RUST_BACKTRACE=1
  RUST_LOG=trace
  BLOCKSTACK_DEBUG=1
}

# Disables debug/trace logging for Stacks binaries
disable_debug() {
  RUST_BACKTRACE=0
  RUST_LOG=info
  BLOCKSTACK_DEBUG=0

}

# Queries the local Stacks node for its info (/v2/info endpoint)
get_node_info() {
  echo "Getting node info"
  # Do something
  node_info=$( curl -s -X GET "localhost:20443/v2/info" | jq "." )
  burn_height=$( jq '.burn_block_height' )
  stacks_height=$( jq '.stacks_tip_height' )

  echo "$node_info"
  echo "$burn_height"
  echo "$stacks_height"
}

dump_logs() {
  tail -n 100 "$NODE_LOG"
}

# Checks the logs from the currently running Stacks node for errors. If any are
# found, the function echos the error message(s) and exits. This function uses
# the shared `running` variable to determine which logs to check.
# This function also searches explicitly for the following strings to determine
# if an error has occurred:
# - error
check_logs_for_errors() {
  if [ "$( tail "$NODE_LOG" | grep -c 'err' )" -gt 0 ]; then
    echo "🔥 Errors were detected!"
    tail "$NODE_LOG" | grep 'error'
    exit 1
  fi
}

print_config() {
  echo "CAT: $( cut -c9- < /proc/1/cpuset )"
  echo
  echo "----------------------------------------"
  echo "Stacks regtest node is starting..."
  echo "Host: ${HOSTNAME}"
  echo "Container id: ${DOCKER_ID}"
  echo "Running as: $( whoami ) ($( id -u ):$( id -g )) groups: [$( groups)]"
  echo "Node version: ${NODE_VERSION}"
  echo "Leader node: ${LEADER}"
  echo "Epoch settings:"
  echo "‣ Stacks 2.0 height: ${STACKS_2_0_HEIGHT}"
  echo "‣ Stacks 2.05 height: ${STACKS_2_05_HEIGHT}"
  echo "‣ Stacks 2.1 height: ${STACKS_2_1_HEIGHT}"
  echo "‣ Stacks 2.2 height: ${STACKS_2_2_HEIGHT}"
  echo "‣ Stacks 2.3 height: ${STACKS_2_3_HEIGHT}"
  echo "‣ Stacks 2.4 height: ${STACKS_2_4_HEIGHT}"
  echo "‣ Stacks 2.5 height: ${STACKS_2_5_HEIGHT}"
  echo "‣ Stacks 3.0 height: ${STACKS_3_0_HEIGHT}"
  echo "Upgrade/start heights:"
  echo "‣ Stacks 2.4 leader node upgrade height: ${STACKS_2_4_LEADER_NODE_UPGRADE_HEIGHT}"
  echo "‣ Stacks 2.4 follower node upgrade height: ${STACKS_2_4_FOLLOWER_NODE_UPGRADE_HEIGHT}"
  echo "‣ Nakamoto leader node start height: ${NAKAMOTO_LEADER_NODE_START_HEIGHT}"
  echo "‣ Nakamoto follower node start height: ${NAKAMOTO_FOLLOWER_NODE_START_HEIGHT}"
  echo "----------------------------------------"
  echo ""
}

validate_node_version() {
  echo "Checking NODE_VERSION..."
  if [ "$NODE_VERSION" != "2.4" ] && [ "$NODE_VERSION" != "nakamoto" ]; then
    echo "❌ NODE_VERSION must be set to either '2.4' or 'nakamoto'"
    exit 1
  fi
  echo "‣ ✓ Node version '$NODE_VERSION' is valid"
}

wait_for_bitcoin_init() {
  iter_count=0
  echo "Waiting for Bitcoin node to start..."
  btc_uptime=$( timeout 15 bash -c 'until bitcoin-cli uptime; do sleep 1; done' )
  if [ -z "$btc_uptime" ]; then
    echo "‣ ❌ Bitcoin node failed to start"
    exit 1
  fi
  echo "‣ ✓ Bitcoin node RPC server is available"

  # Wait for the default wallet to be loaded
  echo "Waiting for default wallet to be created/loaded..."
  default_wallet_exists=0
  until [ "$iter_count" -eq 15 ]; do
    default_wallet_exists="$(bitcoin-cli listwallets | grep -c 'default')"
    if [ "$default_wallet_exists" -eq 1 ]; then
      break
    fi
    echo "‣ Default wallet not found, retrying..."
    sleep 1; 
  done

  if [ "$default_wallet_exists" -eq 0 ]; then
    echo "‣ ❌ Default wallet failed to load"
    exit 1
  fi

  echo "‣ ✓ Default wallet is loaded"
}

configure_node() {
  if [ "$_NODE_CONFIGURED" -eq "$TRUE" ]; then
    return
  fi

  if [ "$LEADER" = true ]; then
    echo "This is a leader node 👑"

    # Move the leader config
    #mv /stacks/conf/leader.toml /stacks/conf/stacks-node.toml

    # Generate a new keychain
    json=$( sbtc generate-from -b testnet -s testnet new )
    btc_address=$( echo "$json" | jq -r '.credentials."0".bitcoin.p2pkh.address' )
    stacks_private_key=$( echo "$json" | jq -r '.credentials."0".stacks.private_key' )
    stacks_address=$( echo "$json" | jq -r '.credentials."0".stacks.address')
    echo "‣ Generated new keychain: BTC: $btc_address, STX: $stacks_address"

    # Replace `seed` and `local_peer_seed` with the new private key
    sed -i 's,^\(seed[ ]*=[ ]*\).*,\1'\""$stacks_private_key"\"',g' /stacks/conf/stacks-node.toml
    sed -i 's,^\(local_peer_seed[ ]*=[ ]*\).*,\1'\""$stacks_private_key"\"',g' /stacks/conf/stacks-node.toml

    # Register the new Bitcoin address with the Bitcoin node
    echo "‣ Registering bitcoin address with bitcoin node: $btc_address"
    bitcoin-cli importaddress "$btc_address" "stacks" false
    echo "‣ ✓ Success!"
  else
    echo "This is a follower node 💤"
    #mv /stacks/conf/follower.toml /stacks/conf/stacks-node.toml
  fi

  touch "$NODE_LOG"

  _NODE_CONFIGURED=$TRUE
}

# Starts a Stacks node using the provided version. This function uses the shared
# `RUNNING` variable and sets it to the version of the node that was started.
start_node() {
  local start_version

  start_version=$1

  # Start the correct Stacks node
  if [ "$start_version" = "2.4" ]; then
    echo "Starting Stacks node 🚀 - v2.4"
    write_2_4_epochs_to_node_config
    RUNNING="2.4"
    echo "### STARTING STACKS NODE - 2.4 ###" >> "$NODE_LOG"
    stacks-node-2.4 start --config /stacks/conf/stacks-node.toml >> "$NODE_LOG" 2>&1 &
  elif [ "$start_version" = "nakamoto" ]; then
    echo "Starting Stacks node 🚀 - Nakamoto"
    write_2_4_epochs_to_node_config # Only if the 2.4 epochs haven't been written yet
    write_nakamoto_epochs_to_node_config # Only if the Nakamoto epochs haven't been written yet
    RUNNING="nakamoto"
    echo "### STARTING STACKS NODE - NAKAMOTO ###" >> "$NODE_LOG"
    stacks-node-nakamoto start --config /stacks/conf/stacks-node.toml >> "$NODE_LOG" 2>&1 &
  fi

  if [ "$LEADER" = true ]; then
    RUNNING="$RUNNING-leader"
  else
    RUNNING="$RUNNING-follower"
  fi

  sleep 1

  if [ "$( is_node_process_alive)" = "1" ]; then
    until [ "$( check_node_startup )" -eq 1 ]; do
      if [ "$( is_node_process_alive )" = "0" ]; then
        echo "‣ 🔥 Node process died unexpectedly"
        dump_logs
        echo "🔥 Please review the above log tail. Exiting."
        exit 1
      fi
      echo "‣ Waiting for node to start..."
      #dump_logs
      sleep 2
    done
  else
    echo "‣ ❌ Node process failed to start"
    dump_logs
    exit 1
  fi

  echo "‣ ✓ Node started"
}

start_signer() {
  # Generate a new keychain
  echo "This is a signer node 🔏"
  json=$( sbtc generate-from -b testnet -s testnet new )
  btc_address=$( echo "$json" | jq -r '.credentials."0".bitcoin.p2pkh.address' )
  stacks_private_key=$( echo "$json" | jq -r '.credentials."0".stacks.private_key' )
  stacks_address=$( echo "$json" | jq -r '.credentials."0".stacks.address')
  echo "‣ Generated new keychain: BTC: $btc_address, STX: $stacks_address"
  echo "‣ Private key: $stacks_private_key"

  echo "Starting Stacks signer 🚀"
  echo "### STARTING STACKS SIGNER ###" >> "$SIGNER_LOG"
  stacks-signer run --config /stacks/conf/stacks-signer.toml --reward-cycle 1 >> "$SIGNER_LOG" 2>&1 &

  while [ "$( is_signer_process_alive )" -eq 0 ]; do
    echo "‣ Letting the signer do its thing..."
    sleep 5
  done
}

# Checks the logs from the currently running Stacks node and looks for the string
# `Start P2P server on`. If found, the function returns (echos) 1, otherwise 0.
# This function uses the shared `running` variable to determine which logs to check.
check_node_startup() {
  local node_log_tail count

  node_log_tail=$( tail "$NODE_LOG" )
  count=$( echo "$node_log_tail" | grep -c -e 'Start P2P server on' -e 'Dispatched result to Relayer')

  if [ "$count" -gt 0 ]; then
    echo $TRUE
    return
  fi

  echo $FALSE
}

# Checks if the Stacks node process is running using `pgrep`. If the process is
# found, the function returns (echos) 1, otherwise 0.
is_node_process_alive() {
  local pid
  
  # Determine the process ID of the running Stacks node
  pid=$( pgrep "stacks-node-" )

  if [ "$pid" = "" ]; then
    echo $FALSE
  else
    echo $TRUE
  fi
}

# Checks if the Stacks signer process is running using `pgrep`. If the process is
# found, the function returns (echos) 1, otherwise 0.
is_signer_process_alive() {
  local pid
  
  # Determine the process ID of the running Stacks node
  pid=$( pgrep --list-full stacks-signer | grep -v bash | awk '{print $1}' )

  if [ "$pid" = "" ]; then
    echo $FALSE
  else
    echo $TRUE
  fi

}

stop_node() {
  local pid

  if [ -z "$RUNNING" ] || [ "$RUNNING" = "stopped" ]; then
    echo "Node is already stopped"
    return
  fi

  pid=$( pgrep --list-full stacks-node | grep -v bash | awk '{print $1}' )

  echo "Stopping Stacks node: $RUNNING ⛔ (pid: $pid)"
  kill -2 "$pid"

  while kill -0 "$pid" 2>/dev/null
  do
    sleep 1
  done

  echo "‣ ✓ Stopped"
  RUNNING="stopped"
}

is_leader() {
  [ "$LEADER" = true ]
}

adjust_epoch() {
  local height this_epoch epoch_name

  height=$1
  this_epoch=${EPOCH_1_0}
  epoch_name="Stacks 1.0"

  if [ "$height" -eq "$STACKS_2_0_HEIGHT" ]; then
    this_epoch=${EPOCH_2_0}
    epoch_name="Stacks 2.0"
  fi
  if [ "$height" -eq "$STACKS_2_05_HEIGHT" ]; then
    this_epoch=${EPOCH_2_05}
    epoch_name="Stacks 2.05"
  fi
  if [ "$height" -eq "$STACKS_2_1_HEIGHT" ]; then
    this_epoch=${EPOCH_2_1}
    epoch_name="Stacks 2.1"
  fi
  if [ "$height" -eq "$STACKS_2_2_HEIGHT" ]; then
    this_epoch=${EPOCH_2_2}
    epoch_name="Stacks 2.2"
  fi
  if [ "$height" -eq "$STACKS_2_3_HEIGHT" ]; then
    this_epoch=${EPOCH_2_3}
    epoch_name="Stacks 2.3"
  fi
  if [ "$height" -eq "$STACKS_2_4_HEIGHT" ]; then
    this_epoch=${EPOCH_2_4}
    epoch_name="Stacks 2.4"
  fi
  if [ "$height" -eq "$STACKS_2_5_HEIGHT" ]; then
    this_epoch=${EPOCH_2_5}
    epoch_name="Stacks 2.5"
  fi
  if [ "$height" -eq "$STACKS_3_0_HEIGHT" ]; then
    this_epoch=${EPOCH_3_0}
    epoch_name="Stacks 3.0"
  fi

  if [ "$this_epoch" -gt "$CURRENT_EPOCH" ]; then
    echo "Epoch reached! 🏁 ($epoch_name @ $height)"
    CURRENT_EPOCH=$this_epoch
  fi
}

write_2_4_epochs_to_node_config() {
  if [ "$_2_4_EPOCHS_WRITTEN" -eq "$TRUE" ]; then
    return
  fi

  cat << EOL >> /stacks/conf/stacks-node.toml

[[burnchain.epochs]]
epoch_name = "1.0"
start_height = 0

[[burnchain.epochs]]
epoch_name = "2.0"
start_height = $STACKS_2_0_HEIGHT

[[burnchain.epochs]]
epoch_name = "2.05"
start_height = $STACKS_2_05_HEIGHT

[[burnchain.epochs]]
epoch_name = "2.1"
start_height = $STACKS_2_1_HEIGHT

[[burnchain.epochs]]
epoch_name = "2.2"
start_height = $STACKS_2_2_HEIGHT

[[burnchain.epochs]]
epoch_name = "2.3"
start_height = $STACKS_2_3_HEIGHT

[[burnchain.epochs]]
epoch_name = "2.4"
start_height = $STACKS_2_4_HEIGHT

EOL

  _2_4_EPOCHS_WRITTEN=$TRUE
}

write_nakamoto_epochs_to_node_config() {
  if [ "$_NAKA_EPOCHS_WRITTEN" -eq "$TRUE" ]; then
    return
  fi

  cat << EOL >> /stacks/conf/stacks-node.toml

[[burnchain.epochs]]
epoch_name = "2.5"
start_height = $STACKS_2_5_HEIGHT

[[burnchain.epochs]]
epoch_name = "3.0"
start_height = $STACKS_3_0_HEIGHT

EOL

  _NAKA_EPOCHS_WRITTEN=$TRUE
}

apply_nakamoto_db_migrations() {
  if [ "$_NAKA_DB_MIGRATIONS_RUN" -eq "$TRUE" ]; then
    return
  fi

  echo "Performing Nakamoto DB migrations..."
  echo "‣ SortitionDB"

  #tree /stacks/data
  #sqlite3 /stacks/data/krypton/burnchain/sortition/marf.sqlite < /stacks/db-migrations/sortition.sql
  echo "‣ ✓ Success!"
}

write_node_info() {
  jq -n \
    --arg bitcoin_block_height "$BITCOIN_BLOCK_HEIGHT" \
    --arg stacks_block_height "$STACKS_BLOCK_HEIGHT" \
    '$ARGS.named' > /stacks/run/container
}

update_stacks_block_height() {
  STACKS_BLOCK_HEIGHT=$( sqlite3 "$NODE_INDEX_DB" "select max(block_height) from block_headers;" )
}

# The main run-loop for the Stacks node. This function is responsible for
# starting the node, checking for new Bitcoin blocks, performing a nakamoto
# node upgrade when configured, and stopping/starting the node when necessary.
run() {
  local last_btc_block_height

  BITCOIN_BLOCK_HEIGHT=$( bitcoin-cli getblockcount )
  last_btc_block_height=$BITCOIN_BLOCK_HEIGHT
  echo "₿ Bitcoin block height: $BITCOIN_BLOCK_HEIGHT"

  # Main loop
  while :
  do
    # Check if we're in a new Bitcoin block
    if [ "$last_btc_block_height" -ne "$BITCOIN_BLOCK_HEIGHT" ]; then
      BITCOIN_BLOCK_HEIGHT=$last_btc_block_height
      echo "₿ New Bitcoin block found: $BITCOIN_BLOCK_HEIGHT"
      adjust_epoch "$BITCOIN_BLOCK_HEIGHT"
      update_stacks_block_height
    fi

    # If the node is not running and has never been started, start the
    # node according to the NODE_VERSION environment variable.
    if [ -z "$RUNNING" ]; then
      start_node "$NODE_VERSION"
    fi

    # Check if we're running a 2.4 leader node and the upgrade height has been
    # reached. If so, stop the 2.4 node and start a Nakamoto node.
    if [ "$RUNNING" = "2.4-leader" ] && [ "$BITCOIN_BLOCK_HEIGHT" -ge "$STACKS_2_4_LEADER_NODE_UPGRADE_HEIGHT" ]
    then
      echo "2.4 leader node upgrade height reached 🚩 (burnchain block $STACKS_2_4_LEADER_NODE_UPGRADE_HEIGHT)"
      stop_node
      enable_debug
      start_node "nakamoto"
    fi
    
    sleep 1

    if [ "$(is_node_process_alive)" -ne $TRUE ]; then
      echo "🔥 Detected that the node process is not running, dumping log tail..."
      dump_logs
      echo "🔥 End of log dump -- exiting"
      exit 1
    fi
    
    last_btc_block_height=$( bitcoin-cli getblockcount )
    write_node_info
  done
}