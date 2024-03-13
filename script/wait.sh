#!/bin/bash

echo "Waiting for the bitcoin RPC server to become available on 18443..."

while ! nc -z localhost 18445; do   
  sleep 0.1 # wait for 1/10 of the second before check again
done

echo "Bitcoin RPC available"
