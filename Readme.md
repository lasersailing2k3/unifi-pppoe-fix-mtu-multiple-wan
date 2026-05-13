# Unifi (Cloud) Gateways PPPoE MTU Fix

This repository contains a set of scripts to enable full RFC4638 support (1500 byte MTU) on Ubiquiti Unifi (Cloud) Gateways running UnifiOS (such as UDM Pro, UDM SE, UCGF, UXG, etc.) when using PPPoE connections.

By default, Unifi OS often limits PPPoE connections to an MTU of 1492. This script forces the correct interface settings to allow a full 1500 byte payload, improving network performance and reducing fragmentation. 

**Feature Update:** This script now fully supports **Multi-WAN setups** (load balancing or failover) with non-blocking interface monitoring to ensure secondary connections are optimized the moment they come online.

## Prerequisites

* Unifi Gateway running UnifiOS (UDM Pro/SE, UCGF, UXG, etc.).
* SSH access enabled on the device.
* One or more PPPoE internet connections (optionally on VLANs).

## Installation

### Quick Install (Recommended)

Run the following command on your Unifi Gateway to download and install the scripts automatically:

```bash
curl -sL https://raw.githubusercontent.com/lasersailing2k3/unifi-pppoe-fix-mtu-multiple-wan/master/install.sh | bash
```

**After installation:**
Check and configure your interfaces in /data/fix-mtu/fix-mtu.conf.

```bash
nano /data/fix-mtu/fix-mtu.conf
```
Update the CONNECTIONS array using the syntax "PPP_INTERFACE:WAN_INTERFACE:VLAN_ID:MTU". If a connection does not use a VLAN, leave the VLAN section blank between the colons.

**Example Configuration:**
```bash
CONNECTIONS=(
    "ppp0:eth8:35:1500" # Primary WAN on eth8 using VLAN 35
    "ppp1:eth7::1500"   # Secondary WAN on eth7 without a VLAN
)
```
**Restart the service to apply changes:**
```bash
systemctl restart fix-mtu
```

### Manual Installation

If you prefer to install manually:

**SSH into your Unifi Gateway:**
```bash
ssh root@<your-gateway-ip>
```

**Prepare the directory:**
Create a persistent directory for the scripts.

```bash
mkdir -p /data/fix-mtu
```
**Copy files:**
Upload fix-mtu.sh, monitor-mtu.sh, fix-mtu.conf, and fix-mtu.service to /data/fix-mtu/ on your Gateway. You can use scp from your local machine:

```bash
scp *mtu* root@<your-gateway-ip>:/data/fix-mtu/
```

**Configure the script:**
Edit the configuration file /data/fix-mtu/fix-mtu.conf:

```bash
vi /data/fix-mtu/fix-mtu.conf
```
**Define your connection array. Adjust the values to match your physical ports and ISP requirements:**
```
bash
CONNECTIONS=(
    "ppp0:eth8:35:1500"
)
```

**Make scripts executable:**
```bash
chmod +x /data/fix-mtu/*.sh
```

**Install and Enable the Service:**
Copy the systemd service file and enable it so it runs on boot.

```bash
cp /data/fix-mtu/fix-mtu.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable fix-mtu
systemctl start fix-mtu
```

**##Important Configuration**

**Disable MSS Clamping:** 
For this fix to work correctly, you must disable MSS Clamping in the Unifi Network application.

Go to Devices and select your Gateway.

Go to Settings (Config) -> Advanced.

Ensure MSS Clamping is set to Auto or Disabled (or Custom with a high value, but Disabled is preferred if the MTU fix works). Note: The original advice suggests disabling it to let the proper MTU negotiation handle packet sizes.

Technical Details: Interface MTUs
When dealing with PPPoE over a VLAN, there is often confusion regarding the correct MTU settings for the parent physical interface versus the VLAN interface.

To achieve a full 1500-byte IP payload:

IP Packet: 1500 bytes.

PPPoE Header: Adds 8 bytes overhead.

Total Frame Size: 1500 + 8 = 1508 bytes.

Why BOTH interfaces must be 1508
You might encounter configurations suggesting the parent interface should be set to 1512 to account for the 4-byte VLAN tag (1508 + 4). However, in the context of the Linux kernel network stack on these devices, this is incorrect.

VLAN Interface (e.g., eth8.35): Must be set to 1508 to accept the full PPPoE frame.

Parent Interface (e.g., eth8): Must also be set to 1508, NOT 1512.

The interface MTU setting defines the maximum size of the payload the interface executes on. When the VLAN interface passes the 1508-byte payload to the parent interface, the parent interface validates that the packet size does not exceed its own MTU. The 4-byte VLAN tag is added by the hardware offloading or driver logic at a layer that typically does not count towards the logical Interface MTU limit for the payload itself.

Setting the parent to 1512 is unnecessary and can sometimes lead to inconsistencies. Both the physical parent and the VLAN child interface should be aligned at 1508 to cleanly pass the RFC4638 compliant PPPoE frames.

References
Unifi Community Thread
