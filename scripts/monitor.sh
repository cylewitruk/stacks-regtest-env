#! /usr/bin/env bash

# Runs as a background process to monitor the state of the regtest environment
# and take action if necessary.
monitor() {
  while : 
  do
    poll_containers
    sleep 1
  done
}