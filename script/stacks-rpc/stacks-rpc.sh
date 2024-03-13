#!/bin/bash

host="https://stacks-node-api.testnet.stacks.co"

PoxInfo() {
    base=$0
    this=$1
    json=$2

    # Extract the fields from the JSON response
    # Define the fields to extract using `jq`
    fields="\
        .contract_id, \
        .pox_activation_threshold_ustx, \
        .first_burnchain_block_height, \
        .current_burnchain_block_height, \
        .prepare_phase_block_length, \
        .reward_phase_block_length, \
        .reward_slots, \
        .rejection_fraction, \
        .total_liquid_supply_ustx, \
        .min_amount_ustx, \
        .prepare_cycle_length, \
        .reward_cycle_id, \
        .reward_cycle_length, \
        .rejection_votes_left_required, \
        .next_reward_cycle_in, \
        .current_cycle.id, \
        .current_cycle.min_threshold_ustx, \
        .current_cycle.stacked_ustx, \
        .current_cycle.is_pox_active, \
        .next_cycle.id, \
        .next_cycle.min_threshold_ustx, \
        .next_cycle.min_increment_ustx, \
        .next_cycle.stacked_ustx, \
        .next_cycle.prepare_phase_start_block_height, \
        .next_cycle.blocks_until_prepare_phase, \
        .next_cycle.reward_phase_start_block_height, \
        .next_cycle.blocks_until_reward_phase, \
        .next_cycle.ustx_until_pox_rejection \
    "

    # Use a direct pipe from `curl` to `jq` and then to `read`
    # This reads the top-level and statically nested fields
    IFS=',' read -r \
        contract_id \
        pox_activation_threshold_ustx \
        first_burnchain_block_height \
        current_burnchain_block_height \
        prepare_phase_block_length \
        reward_phase_block_length \
        reward_slots \
        rejection_fraction \
        total_liquid_supply_ustx \
        min_amount_ustx \
        prepare_cycle_length \
        reward_cycle_id \
        reward_cycle_length \
        rejection_votes_left_required \
        next_reward_cycle_in \
        current_cycle_id \
        current_cycle_min_threshold_ustx \
        current_cycle_stacked_ustx \
        current_cycle_is_pox_active \
        next_cycle_id \
        next_cycle_min_threshold_ustx \
        next_cycle_min_increment_ustx \
        next_cycle_stacked_ustx \
        next_cycle_prepare_phase_start_block_height \
        next_cycle_blocks_until_prepare_phase \
        next_cycle_reward_phase_start_block_height \
        next_cycle_blocks_until_reward_phase \
        next_cycle_ustx_until_pox_rejection \
        < <(curl -s -X GET "$host/v2/pox" | jq -r "[$fields] | @csv")

    # Properties
    export "${this}"_contract_id="${contract_id}"
    export "${this}"_pox_activation_threshold_ustx="${pox_activation_threshold_ustx}"
    export "${this}"_first_burnchain_block_height="${first_burnchain_block_height}"
    export "${this}"_current_burnchain_block_height="${current_burnchain_block_height}"
    export "${this}"_prepare_phase_block_length="${prepare_phase_block_length}"
    export "${this}"_reward_phase_block_length="${reward_phase_block_length}"
    export "${this}"_reward_slots="${reward_slots}"
    export "${this}"_rejection_fraction="${rejection_fraction}"
    export "${this}"_total_liquid_supply_ustx="${total_liquid_supply_ustx}"
    export "${this}"_min_amount_ustx="${min_amount_ustx}"
    export "${this}"_prepare_cycle_length="${prepare_cycle_length}"
    export "${this}"_reward_cycle_id="${reward_cycle_id}"
    export "${this}"_reward_cycle_length="${reward_cycle_length}"
    export "${this}"_rejection_votes_left_required="${rejection_votes_left_required}"
    export "${this}"_next_reward_cycle_in="${next_reward_cycle_in}"
    export "${this}"_current_cycle_id="${current_cycle_id}"
    export "${this}"_current_cycle_min_threshold_ustx="${current_cycle_min_threshold_ustx}"
    export "${this}"_current_cycle_stacked_ustx="${current_cycle_stacked_ustx}"
    export "${this}"_current_cycle_is_pox_active="${current_cycle_is_pox_active}"
    export "${this}"_next_cycle_id="${next_cycle_id}"
    export "${this}"_next_cycle_min_threshold_ustx="${next_cycle_min_threshold_ustx}"
    export "${this}"_next_cycle_min_increment_ustx="${next_cycle_min_increment_ustx}"
    export "${this}"_next_cycle_stacked_ustx="${next_cycle_stacked_ustx}"
    export "${this}"_next_cycle_prepare_phase_start_block_height="${next_cycle_prepare_phase_start_block_height}"
    export "${this}"_next_cycle_blocks_until_prepare_phase="${next_cycle_blocks_until_prepare_phase}"
    export "${this}"_next_cycle_reward_phase_start_block_height="${next_cycle_reward_phase_start_block_height}"
    export "${this}"_next_cycle_blocks_until_reward_phase="${next_cycle_blocks_until_reward_phase}"
    export "${this}"_next_cycle_ustx_until_pox_rejection="${next_cycle_ustx_until_pox_rejection}"

    # Declare methods. (5)
    for method in $(compgen -A function)
    do
        export "${method/#$base\_/$this\_}"="${method} ${this}"
    done
}

v2_pox2() {
    host=$1
    PoxInfo 'v2_pox' "$( curl -s -X GET "$host/v2/pox" )"
}

v2_pox() {
    host=$1

    # Define the fields to extract using `jq`
    fields="\
        .contract_id, \
        .pox_activation_threshold_ustx, \
        .first_burnchain_block_height, \
        .current_burnchain_block_height, \
        .prepare_phase_block_length, \
        .reward_phase_block_length, \
        .reward_slots, \
        .rejection_fraction, \
        .total_liquid_supply_ustx, \
        .min_amount_ustx, \
        .prepare_cycle_length, \
        .reward_cycle_id, \
        .reward_cycle_length, \
        .rejection_votes_left_required, \
        .next_reward_cycle_in, \
        .current_cycle.id, \
        .current_cycle.min_threshold_ustx, \
        .current_cycle.stacked_ustx, \
        .current_cycle.is_pox_active, \
        .next_cycle.id, \
        .next_cycle.min_threshold_ustx, \
        .next_cycle.min_increment_ustx, \
        .next_cycle.stacked_ustx, \
        .next_cycle.prepare_phase_start_block_height, \
        .next_cycle.blocks_until_prepare_phase, \
        .next_cycle.reward_phase_start_block_height, \
        .next_cycle.blocks_until_reward_phase, \
        .next_cycle.ustx_until_pox_rejection \
    "

    response=$( curl -s -X GET "$host/v2/pox" )

    # Print the output of the `jq` command
    echo "Output of jq command:"
    echo "$response" | jq -r "[$fields] | @csv"

    # Use a direct pipe from `curl` to `jq` and then to `read`
    # This reads the top-level and statically nested fields
    IFS=',' read -r \
        contract_id \
        pox_activation_threshold_ustx \
        first_burnchain_block_height \
        current_burnchain_block_height \
        prepare_phase_block_length \
        reward_phase_block_length \
        reward_slots \
        rejection_fraction \
        total_liquid_supply_ustx \
        min_amount_ustx \
        prepare_cycle_length \
        reward_cycle_id \
        reward_cycle_length \
        rejection_votes_left_required \
        next_reward_cycle_in \
        current_cycle_id \
        current_cycle_min_threshold_ustx \
        current_cycle_stacked_ustx \
        current_cycle_is_pox_active \
        next_cycle_id \
        next_cycle_min_threshold_ustx \
        next_cycle_min_increment_ustx \
        next_cycle_stacked_ustx \
        next_cycle_prepare_phase_start_block_height \
        next_cycle_blocks_until_prepare_phase \
        next_cycle_reward_phase_start_block_height \
        next_cycle_blocks_until_reward_phase \
        next_cycle_ustx_until_pox_rejection \
        < <(curl -s -X GET "$host/v2/pox" | jq -r "[$fields] | @csv")

    echo "Contract ID: ${contract_id}"
    echo "POX Activation Threshold USTX: ${pox_activation_threshold_ustx}"
    echo "First Burnchain Block Height: ${first_burnchain_block_height}"
    echo "Current Burnchain Block Height: ${current_burnchain_block_height}"
    echo "Prepare Phase Block Length: ${prepare_phase_block_length}"
    echo "Reward Phase Block Length: ${reward_phase_block_length}"
    echo "Reward Slots: ${reward_slots}"
    echo "Rejection Fraction: ${rejection_fraction}"
    echo "Total Liquid Supply USTX: ${total_liquid_supply_ustx}"
    echo "Minimum Amount USTX: ${min_amount_ustx}"
    echo "Prepare Cycle Length: ${prepare_cycle_length}"
    echo "Reward Cycle ID: ${reward_cycle_id}"
    echo "Reward Cycle Length: ${reward_cycle_length}"
    echo "Rejection Votes Left Required: ${rejection_votes_left_required}"
    echo "Next Reward Cycle In: ${next_reward_cycle_in}"
    echo "Current Cycle ID: ${current_cycle_id}"
    echo "Current Cycle Min Threshold USTX: ${current_cycle_min_threshold_ustx}"
    echo "Current Cycle Stacked USTX: ${current_cycle_stacked_ustx}"
    echo "Current Cycle Is POX Active: ${current_cycle_is_pox_active}"
    echo "Next Cycle ID: ${next_cycle_id}"
    echo "Next Cycle Min Threshold USTX: ${next_cycle_min_threshold_ustx}"
    echo "Next Cycle Min Increment USTX: ${next_cycle_min_increment_ustx}"
    echo "Next Cycle Stacked USTX: ${next_cycle_stacked_ustx}"
    echo "Next Cycle Prepare Phase Start Block Height: ${next_cycle_prepare_phase_start_block_height}"
    echo "Next Cycle Blocks Until Prepare Phase: ${next_cycle_blocks_until_prepare_phase}"
    echo "Next Cycle Reward Phase Start Block Height: ${next_cycle_reward_phase_start_block_height}"
    echo "Next Cycle Blocks Until Reward Phase: ${next_cycle_blocks_until_reward_phase}"
    echo "Next Cycle USTX Until POX Rejection: ${next_cycle_ustx_until_pox_rejection}"

    contract_versions_json=$( echo "$response" | jq -r -c ".contract_versions[]" )
    # shellcheck disable=SC2116
    contract_versions_json_without_quotes=$( echo "${contract_versions_json//\"/""}" )
    mapfile -t all_apps_array < <(echo "$contract_versions_json_without_quotes")
    echo "${all_apps_array[0]}"
    echo "${all_apps_array[1]}"
    echo "${all_apps_array[2]}"

}

v2_pox2 $host
