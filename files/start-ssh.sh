#!/bin/bash

# Setup SSH authorized keys if PUBLIC_KEY is provided
if [ -n "$PUBLIC_KEY" ]; then
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh
    echo "$PUBLIC_KEY" >> ~/.ssh/authorized_keys
    chmod 600 ~/.ssh/authorized_keys
fi

# Ensure the run directory exists for sshd
mkdir -p /run/sshd

# Start sshd in the foreground
exec /usr/sbin/sshd -D
