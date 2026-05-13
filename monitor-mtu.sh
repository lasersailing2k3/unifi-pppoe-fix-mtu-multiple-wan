#!/bin/bash

# Source configuration
cd /data/fix-mtu || exit 1
if [ -f "fix-mtu.conf" ]; then
    source fix-mtu.conf
else
    echo "Config file not found, exiting"
    exit 1
fi

echo "Starting Multi-WAN MTU Monitor..."

# 1. Execute an initial run for any WAN interfaces currently active at boot
/data/fix-mtu/fix-mtu.sh

# 2. Continuously monitor real-time link events
ip monitor link | while read -r line; do
    for conn in "${CONNECTIONS[@]}"; do
        IFS=':' read -r ppp_if wan_if vlan_id mtu <<< "$conn"
        
        # Match exact interface name (e.g., "ppp0:") and MTU parameters
        if [[ "$line" == *"${ppp_if}:"* && "$line" == *"mtu"* ]]; then
            echo "MTU/Link event detected on ${ppp_if}: $line"
            # Allow interface structures in sysfs to populate fully
            sleep 1 
            /data/fix-mtu/fix-mtu.sh "${ppp_if}"
        fi
    done
done
