#!/bin/bash

KEY_DIR="ssh_keys"
mkdir -p $KEY_DIR

COUNT=100  # Change this to 100 if you want 100 keys

for i in $(seq 1 $COUNT); do
    KEY_NAME="$KEY_DIR/server_$i"
    ssh-keygen -t rsa -b 2048 -f "$KEY_NAME" -N ""
    echo "Generated: $KEY_NAME and $KEY_NAME.pub"
done

