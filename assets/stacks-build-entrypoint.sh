#! /usr/bin/env bash
# shellcheck disable=SC2059

mkdir -p /src \
  && cd /src || exit 1

  echo "Cloning repositories" \
  && git clone https://github.com/stacks-network/sbtc.git \
  && git clone https://github.com/hirosystems/clarinet.git --recursive \
  && git clone https://github.com/stacks-network/stacks-core.git

  echo "Building SBTC" \
  && cd /src/sbtc || exit 1 \
  && cargo install --path sbtc-cli --root ./ \
  && mv ./bin/sbtc /stacks/bin/sbtc

  echo "Building Clarinet" \
  && cd /src/clarinet || exit 1 \
  && git submodule update --recursive \
  && cargo build --release --bin clarinet \
  && mv target/release/clarinet /stacks/bin/clarinet 
  
  echo "Building Stacks 2.4 Node" \
  && cd /src/stacks-core || exit 1 \
  && git checkout "${STACKS_2_4_TAG_BRANCH}" \
  && cargo build --package stacks-node --bin stacks-node \
  && cargo build \
  && mv target/debug/stacks-node /stacks/bin/stacks-node-2.4 
  
  echo "Building Nakamoto binaries" \
  && cd /src/stacks-core || exit 1 \
  && git checkout "${STACKS_NAKAMOTO_TAG_BRANCH}" \
  && cargo build --package stacks-node --bin stacks-node \
  && cargo build \
  && mv target/debug/stacks-node /stacks/bin/stacks-node-nakamoto \
  && mv target/debug/blockstack-cli /stacks/bin/blockstack-cli \
  && mv target/debug/stacks-signer /stacks/bin/stacks-signer
