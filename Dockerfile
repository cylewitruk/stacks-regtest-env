ARG USER_ID
ARG GROUP_ID
ARG STACKS_2_4_TAG_BRANCH
ARG NAKAMOTO_TAG_BRANCH

# ------------------------------------------------------------------------------
# Dockerfile to build a Bitcoin Core image for regtest mode
# ------------------------------------------------------------------------------
FROM debian:bookworm-slim as bitcoin-build
ARG BITCOIN_VERSION

# Install dependencies and download Bitcoin Core
RUN apt update \
    && apt install -y wget

WORKDIR /bitcoin

RUN wget https://bitcoincore.org/bin/bitcoin-core-${BITCOIN_VERSION}/bitcoin-${BITCOIN_VERSION}-x86_64-linux-gnu.tar.gz && \
    tar -zxvf bitcoin-${BITCOIN_VERSION}-x86_64-linux-gnu.tar.gz && \
    mkdir -p /bitcoin/bin

# Copy the binaries to the /bitcoin/bin directory & create .bitcoin directory
# for Bitcoin Core configuration
RUN cp bitcoin-${BITCOIN_VERSION}/bin/* /bitcoin/bin/

# ------------------------------------------------------------------------------
# Create a new image with only the runtime dependencies
# ------------------------------------------------------------------------------
FROM debian:bookworm-slim as bitcoind

ARG USER_ID=1000
ARG GROUP_ID=1000

WORKDIR /bitcoin

COPY --from=bitcoin-build /bitcoin/bin /bitcoin/bin/

RUN apt update \
    && apt upgrade \
    && groupadd -r -g ${GROUP_ID} bitcoin \ 
    && useradd -r -m --uid=${USER_ID} -g bitcoin bitcoin \
    && mkdir -p /bitcoin/data \
    && chown -R bitcoin:bitcoin /bitcoin \
    && chmod u+x /bitcoin/bin/* \
    && chmod -R u+rw /bitcoin

USER bitcoin

EXPOSE 18443 18444

ENTRYPOINT ["/bitcoin/entrypoint.sh"]

# ------------------------------------------------------------------------------
# Build stage for Stacks
# ------------------------------------------------------------------------------
FROM rust:1.76-slim-bookworm as stacks-node-build

ARG STACKS_2_4_TAG_BRANCH
ARG STACKS_NAKAMOTO_TAG_BRANCH

WORKDIR /src

# Install dependencies and download stacks-node + sbtc
RUN apt update \
    && apt upgrade -y \
    && apt install -y build-essential libclang-dev git \
    && git clone https://github.com/stacks-network/stacks-core.git \
    && git clone https://github.com/stacks-network/sbtc.git \
    && mkdir -p /stacks/bin

# Build stacks-node 2.4 binary
WORKDIR /src/stacks-core
RUN git checkout ${STACKS_2_4_TAG_BRANCH} \
    && cargo build --package stacks-node --profile dev --bin stacks-node \
    && mv /src/stacks-core/target/debug/stacks-node /stacks/bin/stacks-node-2.4

# Build stacks-node nakamoto binary
RUN git checkout ${STACKS_NAKAMOTO_TAG_BRANCH} \
    && cargo build --package stacks-node --profile dev --bin stacks-node \
    && cargo build --package stacks-signer --profile dev --bin stacks-signer \
    && mv /src/stacks-core/target/debug/stacks-node /stacks/bin/stacks-node-nakamoto \
    && mv /src/stacks-core/target/debug/stacks-signer /stacks/bin/stacks-signer

# Build sbtc cli
WORKDIR /src/sbtc
RUN rustup component add rustfmt \
    && cargo install --path sbtc-cli --root ./ \
    && mv ./bin/sbtc /stacks/bin/sbtc

# ------------------------------------------------------------------------------
# Create a the runtime image with only the runtime dependencies
# ------------------------------------------------------------------------------
FROM debian:bookworm-slim as stacks-node

ARG USER_ID=1000
ARG GROUP_ID=1000

# Copy stacks-node binaries & sbtc cli
COPY --from=stacks-node-build /stacks/bin/* /stacks/bin/
COPY ./assets/stacks-node-entrypoint.sh /stacks/bin/entrypoint.sh
COPY ./assets/stacks-funcs.sh /stacks/bin/stacks-funcs.sh
COPY --from=bitcoin-build /bitcoin/bin/bitcoin-cli /usr/local/bin/bitcoin-cli
COPY ./assets/stacks-leader-conf.toml /stacks/conf/leader.toml
COPY ./assets/stacks-follower-conf.toml /stacks/conf/follower.toml
COPY ./assets/stacks-signer-conf.toml /stacks/conf/signer.toml
COPY ./db-migrations/* /stacks/db-migrations/

RUN apt update \
    && apt upgrade -y \
    && apt install -y jq procps sqlite3 tree \
    && groupadd -r -g ${USER_ID} stacks \ 
    && useradd -r -m --uid ${GROUP_ID} -g stacks stacks \
    && mkdir -p /stacks/signer /stacks/run /bitcoin/data /bitcoin/logs \
    && touch /stacks/run/host /stacks/run/container \
    && chown -R stacks:stacks /stacks \
    && chmod u+x /stacks/bin/* \
    && chown -R stacks:stacks /bitcoin

USER stacks

ENTRYPOINT [ "/bin/bash", "-c", "/stacks/bin/entrypoint.sh" ]