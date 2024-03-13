#!/bin/sh

export PATH="$PATH:/stacks/bin/"

echo "Stacks 3.0 height: ${STACKS_3_0_HEIGHT}"

# Ensure that the node version is set to a valid value
if [ "$NODE_VERSION" != "2.4" ] && [ "$NODE_VERSION" != "nakamoto" ]
then
  echo "❌ NODE_VERSION must be set to either '2.4' or 'nakamoto'"
  exit 1
fi

# Load helper functions
. stacks-funcs.sh

# Wait for the Bitcoin RPC server to start
echo "Waiting for Bitcoin node to start..."
btc_uptime=$( timeout 5 bash -c 'until bitcoin-cli uptime; do sleep 1; done' )
if [ -z "$btc_uptime" ]
then
  echo "‣ ❌ Bitcoin node failed to start"
  exit 1
fi
echo "‣ ✓ Bitcoin node RPC server is available"

# Wait for the default wallet to be loaded
echo "Waiting for default wallet to be created/loaded..."
err=$( timeout 10 bash -c "until [ $(bitcoin-cli listwallets | grep -c 'default') = '1' ]; do sleep 1; done; echo 0;" )
if [ "$err" != "0" ]
then
  echo "‣ ❌ Default wallet failed to load"
  exit 1
fi
echo "‣ ✓ Default wallet is loaded"


# If we're a leader (miner) node, generate a new keychain and import it into
# the Bitcoin node and update the Stacks miner config with the new keychain.
if [ "$LEADER" = true ]
then
  echo "This is a leader node 👑"

  # Move the leader config
  mv /stacks/conf/leader.toml /stacks/conf/stacks-node.toml

  # Generate a new keychain
  json=$( sbtc generate-from -b testnet -s testnet new )
  btc_address=$( echo "$json" | jq -r '.credentials."0".bitcoin.p2pkh.address' )
  stacks_private_key=$( echo "$json" | jq -r '.credentials."0".stacks.private_key' )
  stacks_address=$( echo "$json" | jq -r '.credentials."0".stacks.address')
  echo "‣ New keychain created: BTC: $btc_address, STX: $stacks_address"

  # Replace `seed` and `local_peer_seed` with the new private key
  sed -i 's,^\(seed[ ]*=[ ]*\).*,\1'\""$stacks_private_key"\"',g' /stacks/conf/stacks-node.toml
  sed -i 's,^\(local_peer_seed[ ]*=[ ]*\).*,\1'\""$stacks_private_key"\"',g' /stacks/conf/stacks-node.toml

  # Register the new Bitcoin address with the Bitcoin node
  echo "‣ Registering bitcoin address with bitcoin node: $btc_address"
  bitcoin-cli importaddress "$btc_address" "stacks" false
  echo "‣ ✓ Success!"
else
  echo "This is a follower node"
  mv /stacks/conf/follower.toml /stacks/conf/stacks-node.toml
fi

btc_block_height=$( bitcoin-cli getblockcount )
last_btc_block_height=$btc_block_height
echo "₿ Bitcoin 🔗 block height: $btc_block_height"

while :
do
  if [ "$last_btc_block_height" -ne "$btc_block_height" ]
  then
    echo "₿ New Bitcoin 🔗 block found: $btc_block_height"
    btc_block_height=$last_btc_block_height
  fi

  mkdir -p /stacks/logs /stacks/data

  # Start the correct Stacks node
  if [ "$NODE_VERSION" = "2.4" ] && [ -z "$running" ]
  then
    echo "🚀 Starting Stacks node - v2.4"
    stacks-node-2.4 start --config /stacks/conf/stacks-node.toml > /stacks/logs/stacks-2.4.log 2>&1 &
    running="2.4"
  elif [ "$NODE_VERSION" = "nakamoto" ] && [ -z "$running" ]
  then
    echo "🚀 Starting Stacks node - nakamoto"
    stacks-node-nakamoto start --config /stacks/conf/stacks-node.toml > /stacks/logs/stacks-nakamoto.log 2>&1 &
    running="nakamoto"
  fi

  sleep 1
  
  logrotate "$running"
  last_btc_block_height=$( bitcoin-cli getblockcount )
done