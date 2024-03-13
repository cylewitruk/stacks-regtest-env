#!/bin/sh

json=$(sbtc generate-from -b regtest -s mainnet new)

btc_private_key=$(echo "$json" | jq -r '.private_key')
btc_address=$(echo "$json" | jq -r '.credentials."0".bitcoin.p2tr.address')
stacks_private_key=$(echo "$json" | jq -r '.credentials."0".stacks.private_key')
stacks_public_key=$(echo "$json" | jq -r '.credentials."0".stacks.public_key')
stacks_address=$(echo "$json" | jq -r '.credentials."0".stacks.address')
mnemonic=$(echo "$json" | jq -r '.mnemonic')

echo "mnemonic: $mnemonic"
echo "BTC privkey: $btc_private_key"
echo "BTC address: $btc_address"
echo "Stacks privkey: $stacks_private_key"
echo "Stacks pubkey: $stacks_public_key"
echo "Stacks address: $stacks_address"