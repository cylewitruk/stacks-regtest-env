#! /usr/bin/env bash
# shellcheck disable=SC2059

cd /src || exit 1

# echo "Building SBTC" \
#   && find ./ ! -name '.' -delete \
#   && cp -rT ~/repos/sbtc /src \
#   && git pull \
#   && cargo --config ~/.cargo/config.toml install --path sbtc-cli --root ./ \
#   && mv -f ./bin/sbtc /stacks/bin/sbtc

# echo "Building Clarinet" \
#   && find ./ ! -name '.' -delete \
#   && cp -rT ~/repos/clarinet /src \
#   && git checkout main \
#   && git pull \
#   && git submodule update --recursive \
#   && cargo --config ~/.cargo/config.toml build --profile docker --bin clarinet \
#   && mv -f /target/x86_64-unknown-linux-gnu/docker/clarinet /stacks/bin/clarinet 

echo "Cloning 'stacks-core'" \
  && find ./ ! -name '.' -delete \
  && cp -rT ~/repos/stacks-core /src

echo "Building Stacks 2.4 Node" \
  && git checkout "${STACKS_2_4_TAG_BRANCH}" \
  && cargo --config ~/.cargo/config.toml build --profile docker --package stacks-node --bin stacks-node \
  && mv -f /target/x86_64-unknown-linux-gnu/docker/stacks-node /stacks/bin/stacks-node-2.4 

# echo "Building Nakamoto binaries" \
#   && git checkout "${STACKS_NAKAMOTO_TAG_BRANCH}" \
#   && git pull \
#   && cargo --config ~/.cargo/config.toml build --profile docker --package stacks-node --bin stacks-node \
#   && cargo --config ~/.cargo/config.toml build --profile docker \
#   && mv -f /target/x86_64-unknown-linux-gnu/docker/stacks-node /stacks/bin/stacks-node-nakamoto \
#   && mv -f /target/x86_64-unknown-linux-gnu/docker/blockstack-cli /stacks/bin/blockstack-cli \
#   && mv -f /target/x86_64-unknown-linux-gnu/docker/stacks-signer /stacks/bin/stacks-signer
