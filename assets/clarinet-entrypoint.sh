#! /usr/bin/env bash

# shellcheck disable=SC2034

# Stacks epochs
EPOCH_1_0='1.0'
EPOCH_2_0='2.0'
EPOCH_2_05='2.05'
EPOCH_2_1='2.1'
EPOCH_2_2='2.2'
EPOCH_2_3='2.3'
EPOCH_2_4='2.4'
EPOCH_2_5='2.5'
EPOCH_3_0='3.0'

# Create directory for deployments
mkdir /stacks/deployments
mkdir /stacks/inbox
mkdir /stacks/processing

# Main entry point for the program
main() {
    while : 
    do
        sleep 1
    done
}

# Deploys the Clarinet deployment plan for the provided contract name. Note that
# `generate_deployment()` must have been called for this contract name before
# calling this function.
deploy_contract() {
    local CONTRACT_NAME=$1

    clarinet apply --no-dashboard -p "/stacks/deployments/$CONTRACT_NAME.yaml"
}

# Generates a clarinet deployment plan for a contract.
generate_deployment() {
    local DEPLOYMENT_NAME=$1
    local CONTRACT_NAME=$2
    local STACKS_SENDER=$3
    local EPOCH=$4
    local STACKS_NODE=$5

    envsubst < /stacks/deployment-plan-template.yaml > "/stacks/deployments/$CONTRACT_NAME.yaml"
}

# ==============================================================================
# MAIN PROGRAM ENTRY POINT
# ==============================================================================

# We hide this way down here so that our order of declarations 
# above don't matter =)
main "$@"