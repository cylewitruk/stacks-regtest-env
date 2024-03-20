ARG USER_ID
ARG GROUP_ID
ARG STACKS_2_4_TAG_BRANCH
ARG NAKAMOTO_TAG_BRANCH

# ------------------------------------------------------------------------------
# Build stage for sccache
# ------------------------------------------------------------------------------
FROM rust:1.76-slim-bookworm as build-sccache

RUN apt update \
    && apt upgrade -y \
    && apt install -y pkg-config libssl-dev \
    && rustup toolchain install stable-x86_64-unknown-linux-gnu \
    && cargo install sccache --locked

# ------------------------------------------------------------------------------
# Build stage for Bitcoin Core and other downloaded dependency binaries
# ------------------------------------------------------------------------------
FROM debian:bookworm-slim as download-deps
ARG BITCOIN_VERSION

RUN apt update \
    && apt install -y ca-certificates wget \
    && mkdir /out

# 'dasel' - a jq-like tool for querying and updating JSON, TOML, YAML, etc.
RUN wget -O /out/dasel https://github.com/TomWright/dasel/releases/download/v2.7.0/dasel_linux_amd64

# Bitcoin Core
RUN wget https://bitcoincore.org/bin/bitcoin-core-${BITCOIN_VERSION}/bitcoin-${BITCOIN_VERSION}-x86_64-linux-gnu.tar.gz \
    && tar -zxvf bitcoin-${BITCOIN_VERSION}-x86_64-linux-gnu.tar.gz \
    && cp bitcoin-${BITCOIN_VERSION}/bin/* /out/

RUN chmod +x /out/*

# ------------------------------------------------------------------------------
# Build stage for Stacks Core dependencies and build environment
# ------------------------------------------------------------------------------
FROM rust:1.76-slim-bookworm as build-base
ARG USER_ID
ARG GROUP_ID
ARG BITCOIN_VERSION

COPY --from=build-sccache /usr/local/cargo/bin/sccache /usr/local/cargo/bin/sccache
COPY --from=download-deps /out/bitcoin-cli /usr/local/bin/bitcoin-cli

# Update and install packages
RUN apt update \
    && apt upgrade -y \
    && apt install -y build-essential libclang-dev git wget tree \
        jq libssl-dev pkg-config libfontconfig-dev libsqlite3-dev \
        gcc-multilib clang mold libsecp256k1-1 libsecp256k1-dev \
        procps

#RUN rustup toolchain install stable-x86_64-unknown-linux-gnu \
#    && rustup default stable-x86_64-unknown-linux-gnu \
#    && rustup toolchain uninstall 1.76.0-x86_64-unknown-linux-gnu \
RUN rustup component add rustfmt

# Create our non-root user & group ('stacks')
RUN groupadd -r -g ${GROUP_ID} stacks \
    && useradd -r -m --uid ${GROUP_ID} -g ${GROUP_ID} stacks \
    && install -d -m 0755 -o stacks -g stacks \
        /src \
        /sccache \
        /target \
        /stacks \
        /bitcoin

USER stacks
COPY --chown=stacks:stacks --from=download-deps /out/* /home/stacks/bin/
COPY --chown=stacks:stacks ./assets/cargo-config.toml /home/stacks/.cargo/config.toml

RUN mkdir ~/repos \
    && cd ~/repos \
    && git clone https://github.com/stacks-network/stacks-core.git \
    && git clone https://github.com/stacks-network/sbtc.git \
    && git clone https://github.com/hirosystems/clarinet.git --recursive \
    && touch ~/stacks-core-deps

#ENV RUSTC_WRAPPER /usr/local/cargo/bin/sccache
ENV CARGO_INCREMENTAL 0
ENV SCCACHE_DIRECT true
ENV SCCACHE_DIR /sccache
ENV CARGO_TARGET_DIR /target

WORKDIR /src

# RUN cp -rT ~/repos/stacks-core /src \
#     # Read dependencies for 'main' branch
#     && cargo tree --prefix none --depth 1 --workspace -q -e normal --format "{p} {f}" \
#         | grep -v "$PWD" | grep -v "https://" | sort | uniq -u >> ~/stacks-core-deps \
#     # Read dependencies for 'develop' branch
#     && git checkout develop \
#     && cargo tree --prefix none --depth 1 --workspace -q -e normal --format "{p} {f}" \
#         | grep -v "$PWD" | grep -v "https://" | sort | uniq -u >> ~/stacks-core-deps \
#     # Read dependencies for 'next' branch
#     && git checkout next \
#     && cargo tree --prefix none --depth 1 --workspace -q -e normal --format "{p} {f}" \
#         | grep -v "$PWD" | grep -v "https://" | sort | uniq -u >> ~/stacks-core-deps \
#     # Delete all files in /src
#     && find ./ ! -name '.' -delete

# RUN cp -rT ~/repos/clarinet /src \
#     # Read dependencies for 'main' branch
#     && cargo tree --prefix none --depth 1 --workspace -q -e normal --format "{p} {f}" \
#         | grep -v "$PWD" | grep -v "https://" | sort | uniq -u >> ~/stacks-core-deps \
#     # Delete all files in /src
#     && find ./ ! -name '.' -delete

# # Init a new 'lib' crate here. We use its Cargo.toml as a base for the
# # final Cargo.toml including all dependencies read from above.
# RUN cargo init --lib
# # Read the ~/stacks-core-deps file and format all of the dependencies as 
# # Cargo.toml entries. We sort the entries by package name and version,
# # and then by feature set. We then remove duplicate entries for the same
# # package name and version, keeping the one with the highest version.
# RUN cat ~/stacks-core-deps | sort | uniq -u | awk '{gsub(/v/, "", $2); gsub(/ \(.*\)$/, "", $1); gsub(/\(.*\)/, "", $3); if ($3 == "" || $3 == "\"\"") $3 = ""; \
#         else {gsub(/,/, "\",\"", $3); $3 = ", features = [\"" $3 "\"]"}; \
#         print $1 " = { version = \"" $2 "\"" $3 " }"}' \
#         | sort -t= -k1,1 -k3,3nr | awk -F= '!seen[$1]++' \
#         >> Cargo.toml

# # Build the dependencies using the 'docker' profile. This profile is used to
# # ensure that the build is reproducible and that the build artifacts are
# # cached correctly by sccache.
# RUN cargo --config ~/.cargo/config.toml build --verbose --profile docker >> ~/build-log 2>&1 | tee \
#     && find ./ ! -name '.' -delete \
#     && sccache -s > ~/sccache-stats
#     #&& cp -rT ~/repos/stacks-core /src \
#     #&& cargo --config ~/.cargo/config.toml build --verbose --package stacks-node --bin stacks-node --profile docker >> ~/build-log 2>&1 | tee \
#     #&& sccache -s >> ~/sccache-stats \
#     #&& find ./ ! -name '.' -delete

WORKDIR /home/stacks

# ------------------------------------------------------------------------------
# Build stage for Stacks Core dependencies and build environment
# ------------------------------------------------------------------------------
FROM debian:bookworm-slim as runtime
ARG USER_ID
ARG GROUP_ID
ARG BITCOIN_VERSION

COPY --from=download-deps /out/bitcoin-cli /usr/local/bin/bitcoin-cli
COPY --from=download-deps /out/bitcoind /usr/local/bin/bitcoind
COPY --from=download-deps /out/dasel /usr/local/bin/dasel

RUN apt update \
    && apt upgrade -y \
    && apt install -y procps sqlite3 jq

# Create our non-root user & group ('stacks')
RUN groupadd -r -g ${GROUP_ID} stacks \
    && useradd -r -m --uid ${GROUP_ID} -g ${GROUP_ID} stacks \
    && install -d -m 0755 -o stacks -g stacks \
        /src \
        /sccache \
        /target \
        /stacks \
        /stacks/logs \
        /stacks/bitcoin \
        /stacks/conf

WORKDIR /home/stacks

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
# Build stage for Stacks Nodes
# ------------------------------------------------------------------------------
FROM rust:1.76-slim-bookworm as stacks-build
ARG STACKS_2_4_TAG_BRANCH
ARG STACKS_NAKAMOTO_TAG_BRANCH

WORKDIR /src

# Install dependencies and download stacks-node + sbtc
RUN apt update \
    && apt upgrade -y \
    && apt install -y build-essential libclang-dev git wget \
    && git clone https://github.com/stacks-network/stacks-core.git \
    && git clone https://github.com/stacks-network/sbtc.git \
    && git clone https://github.com/hirosystems/clarinet.git --recursive \
    && rustup toolchain install stable-x86_64-unknown-linux-gnu \
    && rustup component add rustfmt \
    && mkdir -p /stacks/bin

RUN wget -O /usr/local/bin/dasel https://github.com/TomWright/dasel/releases/download/v2.7.0/dasel_linux_amd64 \
    && chmod +x /usr/local/bin/dasel

# Build stacks-node 2.4 binary
WORKDIR /src/stacks-core
RUN git checkout ${STACKS_2_4_TAG_BRANCH} \
    && cargo build --package stacks-node --bin stacks-node \
    && cargo build \
    && mv /src/stacks-core/target/debug/stacks-node /stacks/bin/stacks-node-2.4

# Build stacks-node nakamoto binary
RUN git checkout ${STACKS_NAKAMOTO_TAG_BRANCH} \
    && cargo build --package stacks-node --bin stacks-node \
    && cargo build \
    && mv /src/stacks-core/target/debug/stacks-node /stacks/bin/stacks-node-nakamoto \
    && mv /src/stacks-core/target/debug/blockstack-cli /stacks/bin/blockstack-cli \
    && mv /src/stacks-core/target/debug/stacks-signer /stacks/bin/stacks-signer

# Build clarinet
WORKDIR /src/clarinet
RUN git checkout main \
    && git pull \
    && git submodule update --recursive \
    && cargo build --release --bin clarinet \
    && mv target/release/clarinet /stacks/bin/clarinet

# Build sbtc cli
WORKDIR /src/sbtc
RUN cargo install --path sbtc-cli --root ./ \
    && mv ./bin/sbtc /stacks/bin/sbtc

# ------------------------------------------------------------------------------
# Stacks node runtime image
# ------------------------------------------------------------------------------
FROM debian:bookworm-slim as stacks-node
ARG USER_ID=1000
ARG GROUP_ID=1000

# Copy stacks-node binaries & sbtc cli
COPY --from=stacks-build /stacks/bin/* /stacks/bin/
COPY --from=bitcoin-build /bitcoin/bin/bitcoin-cli /usr/local/bin/bitcoin-cli

# Copy local assets
#COPY ./assets/stacks-node-entrypoint.sh /stacks/bin/entrypoint.sh
#COPY ./assets/stacks-funcs.sh /stacks/bin/stacks-funcs.sh
#COPY ./assets/stacks-leader-conf.toml /stacks/conf/leader.toml
#COPY ./assets/stacks-follower-conf.toml /stacks/conf/follower.toml
#COPY ./assets/stacks-signer-conf.toml /stacks/conf/signer.toml
#COPY ./db-migrations/* /stacks/db-migrations/

RUN apt update \
    && apt upgrade -y \
    && apt install -y jq procps sqlite3 tree \
    && groupadd -r -g ${USER_ID} stacks \ 
    && useradd -r -m --uid ${GROUP_ID} -g stacks stacks \
    #&& mkdir -p /stacks/signer /stacks/run /bitcoin/data /bitcoin/logs \
    #&& touch /stacks/run/host /stacks/run/container \
    && chown -R stacks:stacks /stacks \
    && chmod u+x /stacks/bin/* \
    && chown -R stacks:stacks /bitcoin

USER stacks

ENTRYPOINT [ "/bin/bash", "-c", "/stacks/bin/entrypoint.sh" ]

# ------------------------------------------------------------------------------
# Clarinet runtime image
# ------------------------------------------------------------------------------
FROM debian:bookworm-slim as clarinet
ARG USER_ID=1000
ARG GROUP_ID=1000

WORKDIR /stacks

# Copy blockstack-cli and clarinet binary & examples
COPY --from=stacks-build /stacks/bin/blockstack-cli /stacks/bin/blockstack-cli
COPY --from=stacks-build /stacks/bin/clarinet /stacks/bin/clarinet
COPY --from=stacks-build /src/clarinet/components/clarinet-cli/examples /stacks/apps

# Copy local assets
COPY ./assets/clarinet-entrypoint.sh /stacks/bin/entrypoint.sh
COPY ./assets/clarinet-deployment-plan.yaml /stacks/deployment-plan-template.yaml

# Update and install packages
RUN apt update \
    && apt upgrade -y \
    && apt install -y jq tree gettext-base wget \
    && wget -O /usr/local/bin/dasel https://github.com/TomWright/dasel/releases/download/v2.7.0/dasel_linux_amd64 \
    && chmod +x /usr/local/bin/dasel

# Create stacks user/group, create needed directories and set permissions
RUN groupadd -r -g ${USER_ID} stacks \ 
    && useradd -r -m --uid ${GROUP_ID} -g stacks stacks \
    && mkdir -p /stacks/run \
    && touch /stacks/run/host /stacks/run/container \
    && chown -R stacks:stacks /stacks \
    && chmod u+x /stacks/bin/* \
    && ln -s /stacks/bin/clarinet /bin/clarinet

ENTRYPOINT [ "/stacks/bin/entrypoint.sh"]