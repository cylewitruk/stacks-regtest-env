_Docs are WIP!_

# Stacks Regtest Environment
This project aims to simplify the process of configuring and running a [Stacks Blockchain](https://www.stacks.co/) `regtest` environment.

This application is an assortment of `bash` scripts which provide a clean interface over a number of different tools. While POSIX `sh` compatability isn't far away, I chose `bash` as it's still very widespread and there are some nice features for larger shellscript applications.

## Index
- [Stacks Regtest Environment](#stacks-regtest-environment)
  - [Index](#index)
  - [Requirements](#requirements)
  - [How it Works](#how-it-works)
    - [Docker](#docker)
    - [Environments](#environments)
    - [Data Synchronization](#data-synchronization)
      - [Mounted Volumes](#mounted-volumes)
      - [Synchronized Data](#synchronized-data)
  - [Usage](#usage)
    - [Starting a New Environment](#starting-a-new-environment)
    - [Stopping the Environment](#stopping-the-environment)
    - [Viewing the Environment](#viewing-the-environment)
    - [Cleaning Up](#cleaning-up)

## Requirements
This application requires the following dependencies on the local machine:
- bash
- docker (& compose)

## How it Works

### Docker
The scripts make heavy use of Docker to both build and run environments.

All container details can be found in the `Dockerfile` which uses multi-stage/multi-target as we're building a number of binaries used in several final images.

Here's a summary of the build stages:
- `bitcoin-build`: This stage downloads and extracts the Bitcoin Core binaries for the specified Bitcoin version. By default, the binaries are retrieved from bitcoincore.org, this can however be overridden in the `.env` file.
- `bitcoind`: This is the final Bitcoin node image. We only copy the required binaries from `bitcoin-build` to keep the size down, and we copy our local assets.
- `stacks-build`: This is the "big one". Here we pull down all of the Stacks-related source code and build `stacks-node` (twice - once for `2.4` and once for `nakamoto`), `stacks-signer`, `clarinet`, `blockstack-cli` and `sbtc` binaries. This build stage will take a while on the first run :)
- `stacks-node`: This is the runtime image for Stacks nodes and signers. This image contains both the `2.4` and `nakamoto` versions of `stacks-node`, `blockstack-cli` as well as `sbtc` and `bitcoin-cli`.
- `clarinet`: This image contains the `clarinet` binary and is used to interact with contracts within the environment.

Containers are labeled with a few Stacks-specific labels to help us distinguish between services:
- `local.stacks.environment_id`: The environment id (see [Environments](#environments)).
- `local.stacks.role`: The role of the container (one of `node`, `bitcoind`, `signer`, `environment`).
- `local.stacks.node_version`: The **startup** version of containers with the `node` role. For example, if a `2.4` node is started but is upgraded to a `nakamoto` node, this label will remain `2.4.`. This is used to visualize upgrade paths in the `ls` command.
- `local.stacks.leader`: Indicates whether or not a container with the `node` role is a leader (_miner_) or not (_follower_).

### Environments
This tool uses the concept of _environments_ which keep individual regtest environments isolated from eachother.

Each environment is assigned a unique identifier in the format `yyyyMMddHHmmS`. The script will use this identifier to create a new "assets" directory under `./environments` specific to that environment. All docker containers will also be labeled with `local.stacks.environment_id=REGTEST_ENV_ID` so that we ensure we only touch containers which belong to the environment.

When the environment is starting, first a small `busybox` container (~3MB) will be started and labeled with the above. This container represents the "liveliness" of the environment and simply runs a while/sleep loop until it's killed.

Next, the other requested services will be started as well as a background "monitor" task which both monitors the state of the environment and performs [data synchronization](#data-synchronization) between active services.

### Data Synchronization
_We'll use the **environment id** of `2024010110101` and Docker container id `99e74a576e79` for examples in this section._

#### Mounted Volumes

The logs for running services are mounted to the local `logs` directory associated with the environment. For example, the logs directory for the above example would be `./environments/2024010110101/logs`. 

Each container is responsible for writing its own logs, and for services which can have multiple instances will append their container id to the filename, for example `stacks-node-99e74a576e79.log` for the above container.

#### Synchronized Data

The `monitor.sh` script is responsible for synchronizing data between the host and running services, when an environment is active. 

TODO

## Usage

```
Usage: 
  ./regtest COMMAND [OPTIONS]

Available Commands:
  build                     Build the regtest environment.
  start                     Start the regtest environment.
  ls                        List all running services for the current
                              environment.
  clean                     Clean regtest data from disk. If there is an active
                              environment, it will be skipped.
  epochs                    Print a list of available epochs for the regtest
                              environment.

Environment Commands:
These commands require a running environment.
  stop                      Stop the currently running environment.
  contract-deploy           Deploy a contract to the active environment.
  contract-call             Call a public or read-only function on a contract
                              in the active environment.

Other:
  help, -h, --help          Print this help message
```

### Starting a New Environment
The `start` command is used to setup and start a new regtest environment. Here's an exerpt from the command's help:
```
Starts the regtest environment with the specified configuration.
* At least one node (-n|--node) must be specified to start the environment.

Usage:
   ./regtest.sh start [OPTIONS]

Examples:
   # Start all nodes
   ./regtest start --all-nodes

   # Start the 24 leader and Naka follower nodes
   ./regtest start --node 24L --node NF

   # Start the 24 leader and 2 signer nodes
   ./regtest start --node 24-leader --signers 2

   # Start all nodes without installing default contracts
   ./regtest start --all-nodes --no-default-contracts

Available Options:
  -a, --all-nodes           Start all nodes.
  -s, --signers int         Optionally start the specified number of
                              signer nodes. This option may only be used once.
  -n, --node <node>         Start a specific node. This option may be
                              used multiple times to start multiple nodes,
                              i.e. --node 24-leader --node naka-leader.
                              May not be used in combination with --all-nodes.
                              The following node names are valid:
                                - 24-leader, 24L
                                - 24-follower, 24F
                                - naka-leader, NL
                                - naka-follower, NF
  --no-default-contracts    Does not install any default contracts into the
                              environment.
  -h, --help                Print this help message.
```

### Stopping the Environment
The `stop` command is used to stop the environment. Note that environment data will not be automatically cleaned up -- see [cleaning up](#cleaning-up).

### Viewing the Environment
The `ls` command can be used to view the current status of the environment.

Example of a result from `./regtest ls`:
```
NAME                                    ROLE              VERSION
local-stacks-naka-follower-node-1       node              nakamoto
local-stacks-naka-leader-node-1         node (leader)     nakamoto
local-stacks-naka-follower-node-2       node              nakamoto
local-stacks-2.4-leader-node-1          node (leader)     2.4
local-bitcoin-node-1                    bitcoind

This environment has a total of 5 active services (excluding hidden)
```

Note that if a `node` has been upgraded while running, it will be reflected in the `VERSION` column of the table, for example:
```
local-stacks-2.4-leader-node-1          node (leader)     2.4 ⇾ nakamoto
```

### Cleaning Up
Data will never be automatically removed from environments. However, the `clean` command is available which will remove all stale environment data. Note that if there is currently an running environment, it will **not** be cleaned up.