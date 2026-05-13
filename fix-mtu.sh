#!/bin/bash

# Source configuration
cd /data/fix-mtu || exit 1
if [ -f "fix-mtu.conf" ]; then
    source fix-mtu.conf
else
    echo "Config file not found, exiting"
    exit 1
fi

apply_fix() {
    local ppp_if="$1"
    local wan_if="$2"
    local vlan_id="$3"
    local mtu="$4"

    local mtupath="/sys/class/net/${ppp_if}/mtu"

    if [ ! -f "$mtupath" ]; then
        echo "${ppp_if} device not ready, skipping..."
        return 0
    fi

    local interface_mtu
    interface_mtu=$(cat "$mtupath")

    if [ "$interface_mtu" -ne "$mtu" ]; then
        echo "MTU for ${ppp_if} is $interface_mtu, changing to $mtu"
        
        # Update peer config if present
        if [ -f "/etc/ppp/peers/${ppp_if}" ]; then
            sed -i "s/ ${interface_mtu}/ ${mtu}/g" "/etc/ppp/peers/${ppp_if}"
        fi

        # Adjust physical parent interface MTU (+8 for PPPoE overhead)
        ip link set dev "${wan_if}" mtu $(( mtu + 8 ))

        # Adjust VLAN child interface MTU if configured
        if [ -n "$vlan_id" ]; then
            ip link set dev "${wan_if}.${vlan_id}" mtu $(( mtu + 8 ))
        fi

        # Gracefully target the specific pppd process to avoid dropping other WANs
        if [ -f "/var/run/${ppp_if}.pid" ]; then
            kill "$(cat "/var/run/${ppp_if}.pid")" 2>/dev/null
        else
            pkill -f "${ppp_if}" 2>/dev/null || killall pppd 2>/dev/null
        fi

        sleep 1
        killall -HUP dnscrypt-proxy dnsmasq 2>/dev/null
    else
        echo "MTU for ${ppp_if} is OK ($interface_mtu)"
    fi
}

TARGET_IF="$1"

# Loop through configured connections
for conn in "${CONNECTIONS[@]}"; do
    IFS=':' read -r ppp_if wan_if vlan_id mtu <<< "$conn"
    
    # If triggered by monitor-mtu.sh for a specific interface, skip the others
    if [ -n "$TARGET_IF" ] && [ "$TARGET_IF" != "$ppp_if" ]; then
        continue
    fi
    
    apply_fix "$ppp_if" "$wan_if" "$vlan_id" "$mtu"
done
