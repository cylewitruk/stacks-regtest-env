#!/bin/sh

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

CURRENT_EPOCH=$EPOCH_1_0

TRUE=1
FALSE=0

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

# Rotates the logs for the running Stacks node. This uses the shared `running`
# variable to determine which logs to rotate.
logrotate() {
    logfile="$( get_active_log_file )"
    # shellcheck disable=SC2005
    echo "$( tail -c 100K "$logfile" )" > "$logfile"
}

# Checks the logs from the currently running Stacks node and looks for the string
# `Start P2P server on`. If found, the function returns (echos) 1, otherwise 0.
# This function uses the shared `running` variable to determine which logs to check.
check_node_startup() {
    logfile="$( get_active_log_file )"

    if [ "$( tail -n 500 "$logfile" | grep -c 'Start P2P server on' )" -eq 1 ]; then
        echo 1
        return
    fi

    echo 0
}

get_active_log_file() {
    if [ "$running" = "2.4-leader" ] || [ "$running" = "2.4-follower" ]; then
        echo "/stacks/logs/stacks-2.4.log"
        return
    elif [ "$running" = "nakamoto-leader" ] || [ "$running" = "nakamoto-follower" ]; then
        echo "/stacks/logs/stacks-nakamoto.log"
    fi
}

dump_logs() {
    logfile="$( get_active_log_file )"
    tail -n 100 "$logfile"
}

# Checks the logs from the currently running Stacks node for errors. If any are
# found, the function echos the error message(s) and exits. This function uses
# the shared `running` variable to determine which logs to check.
# This function also searches explicitly for the following strings to determine
# if an error has occurred:
# - error
check_logs_for_errors() {
    if [ "$( tail "$( get_active_log_file )" | grep -c 'err' )" -gt 0 ]; then
        echo "🔥 Errors were detected!"
        tail "$( get_active_log_file )" | grep 'error'
        exit 1
    fi
}

print_config() {
    echo "----------------------------------------"
    echo "Stacks regtest node is starting..."
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
    if [ "$LEADER" = true ]; then
        echo "This is a leader node 👑"

        # Move the leader config
        mv /stacks/conf/leader.toml /stacks/conf/stacks-node.toml

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
        mv /stacks/conf/follower.toml /stacks/conf/stacks-node.toml
    fi
}

start_node() {
    start_version=$1

    # Start the correct Stacks node
    if [ "$start_version" = "2.4" ]; then
        echo "Starting Stacks node 🚀 - v2.4"
        running="starting"
        stacks-node-2.4 start --config /stacks/conf/stacks-node.toml > /stacks/logs/stacks-2.4.log 2>&1 &
        running="2.4"
    elif [ "$start_version" = "nakamoto" ]; then
        echo "Starting Stacks node 🚀 - Nakamoto"
        running="starting"
        stacks-node-nakamoto start --config /stacks/conf/stacks-node.toml > /stacks/logs/stacks-nakamoto.log 2>&1 &
        running="nakamoto"
    fi

    if [ "$LEADER" = true ]; then
        running="$running-leader"
    fi

    if [ "$( is_node_process_alive)" = "1" ]; then
        until [ "$( check_node_startup )" -eq 1 ]; do
            if [ "$( is_node_process_alive )" = "0" ]; then
                echo "‣ 🔥 Node process died unexpectedly"
                dump_logs
                echo "‣ 🔥 Please review the above log tail. Exiting."
                exit 1
            fi

            echo "‣ Waiting for node to start..."
            logrotate
            check_logs_for_errors
            sleep 2
        done
    else
        echo "‣ ❌ Node process failed to start"
        dump_logs
        exit 1
    fi

    echo "‣ ✓ Node started"
}

is_node_process_alive() {
    pid=$( pgrep -f "stacks-node-" )
    if [ -z "$pid" ]; then
        echo "0"
    else
        echo "1"
    fi
}

stop_node() {
    if [ -z "$running" ] || [ "$running" = "stopped" ]; then
        echo "Node is already stopped"
        return
    fi

    pid=$( pgrep -f "stacks-node-" )

    echo "Stopping Stacks node: $running ⛔ (pid: $pid)"
    kill -2 "$pid"

    while kill -0 "$pid" 2>/dev/null
    do
        sleep 1
    done

    echo "‣ ✓ Stopped"
    running="stopped"
}

is_leader() {
    [ "$LEADER" = true ]
}

adjust_epoch() {
    height=$1
    this_epoch=${EPOCH_1_0}
    epoch_name="Stacks 1.0"

    if [ "$height" -gt "$STACKS_2_0_HEIGHT" ]; then
        this_epoch=${EPOCH_2_0}
        epoch_name="Stacks 2.0"
    fi
    if [ "$height" -gt "$STACKS_2_05_HEIGHT" ]; then
        this_epoch=${EPOCH_2_05}
        epoch_name="Stacks 2.05"
    fi
    if [ "$height" -gt "$STACKS_2_1_HEIGHT" ]; then
        this_epoch=${EPOCH_2_1}
        epoch_name="Stacks 2.1"
    fi
    if [ "$height" -gt "$STACKS_2_2_HEIGHT" ]; then
        this_epoch=${EPOCH_2_2}
        epoch_name="Stacks 2.2"
    fi
    if [ "$height" -gt "$STACKS_2_3_HEIGHT" ]; then
        this_epoch=${EPOCH_2_3}
        epoch_name="Stacks 2.3"
    fi
    if [ "$height" -gt "$STACKS_2_4_HEIGHT" ]; then
        this_epoch=${EPOCH_2_4}
        epoch_name="Stacks 2.4"
    fi
    if [ "$height" -gt "$STACKS_2_5_HEIGHT" ]; then
        this_epoch=${EPOCH_2_5}
        epoch_name="Stacks 2.5"
    fi
    if [ "$height" -gt "$STACKS_3_0_HEIGHT" ]; then
        this_epoch=${EPOCH_3_0}
        epoch_name="Stacks 3.0"
    fi

    if [ "$this_epoch" -gt "$CURRENT_EPOCH" ]; then
        echo "Epoch reached! 🏁 ($epoch_name @ $height)"
        CURRENT_EPOCH=$this_epoch
    fi
}