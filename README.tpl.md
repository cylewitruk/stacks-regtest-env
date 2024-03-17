_Docs are WIP!_

# Stacks Regtest Environment
This project aims to simplify the process of configuring and running a [Stacks Blockchain](https://www.stacks.co/) `regtest` environment.

This application is an assortment of `bash` scripts which provide a clean interface over a number of different tools. While POSIX `sh` compatability isn't far away, I chose `bash` as it's still very widespread and there are some nice features for larger shellscript applications.

## Index
- [Stacks Regtest Environment](#stacks-regtest-environment)
  - [Index](#index)
  - [Requirements](#requirements)
  - [Usage](#usage)
    - [Starting a New Environment](#starting-a-new-environment)
    - [Data Synchronization](#data-synchronization)
      - [Synchronized Data](#synchronized-data)
    - [Cleaning Up](#cleaning-up)

## Requirements
This application requires the following dependencies on the local machine:
- bash
- docker (& compose)


## Usage

```
${USAGE_MAIN}
```

### Starting a New Environment
The `start` command is used to setup and start a new regtest environment. Here's an exerpt from the command's help:
```
${USAGE_START}
```
Each environment is assigned a unique identifier in the format `yyyyMMddHHmmS`. The script will use this identifier to create a new "assets" directory under `./environments` specific to that environment. All docker containers will also be labeled with `local.stacks.environment_id=REGTEST_ENV_ID` so that we ensure we only touch containers which belong to the environment.

When the environment is starting, first a small `busybox` container will be started and labeled with the above. This container represents the "liveliness" of the environment.

Next, the other requested services will be started as well as a background "monitor" task which both monitors the state of the environment and performs [data synchronization](#data-synchronization) between active services.

### Data Synchronization
_We'll use the **environment id** of `2024010110101` and Docker container id `99e74a576e79` for examples in this section._

The logs for running services are mounted to the local `logs` directory associated to the Docker `container id` as a Docker volume in the respective environment's path. For example, a logs directory may be `./environments/2024010110101/99e74a576e79/logs`.

The `monitor.sh` script is responsible for synchronizing data between the host and running services, when an environment is active. 

#### Synchronized Data
- Logs

TODO

### Cleaning Up
Data will never be automatically removed from environments.