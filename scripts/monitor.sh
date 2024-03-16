#! /usr/bin/env bash

# Runs as a background process to monitor the state of the regtest environment
# and take action if necessary.
monitor() {
    while : 
    do
        echo "Monitor loop..."
        poll_containers
        sleep 5
    done
}