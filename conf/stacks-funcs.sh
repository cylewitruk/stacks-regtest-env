#!/bin/sh

# Queries the local Stacks node for its info (/v2/info endpoint)
get_node_info() {
  echo "Getting node info"
  # Do something
  node_info=$( curl -s -X GET "localhost:20443/v2/info" | jq "." )
  burn_height=$( jq '.burn_block_height' )
  stacks_height=$( jq '.stacks_tip_height' )

  echo "$node_info"
  echo "$burn_height"
  echo "$stacks_height"
}

logrotate() {
    version=$1
    if [ "$version" = "2.4" ]
    then
        # shellcheck disable=SC2005
        echo "$( tail -c 100K /stacks/logs/stacks-2.4.log )" > /stacks/logs/stacks-2.4.log
        #tail /stacks/logs/stacks-2.4.log
    elif [ "$version" = "nakamoto" ]
    then
        # shellcheck disable=SC2005
        echo "$( tail -c 100K /stacks/logs/stacks-nakamoto.log )" > /stacks/logs/stacks-nakamoto.log
        #tail /stacks/logs/stacks-nakamoto.log
    fi
}