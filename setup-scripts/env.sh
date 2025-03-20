#!/bin/bash

# This script installs the required components to run FLUIDOS on a K3s cluster.
# if you use this script, make sure that the ip address of the machine does not change or it could break the metallb configuration
ARCHITECTURE=$(uname -m)


NXP_S32=0

NODE_NAME=$(hostname)
LIQOCTL_VERSION="v0.10.3"
FLUIDOS_VERSION="0.1.1"
K9S_VERSION="v0.32.7"
REAR_PORT=30000
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
USER_HOME=$(eval echo ~$USER)

# loadbalancer config
METALLB_ADDRESS_POOL_NAME="default"

# Network Manager
ENABLE_LOCAL_DISCOVERY=true
FIRST_OCTET=10 # Change this to the first octet of the IP address range of the pod cidr, in k3s it is usually 10
SECOND_OCTET=42 # Change this to the second octet of the IP address range of the pod cidr, in k3s it is usually 42

# use a different value for the third octet for each cluster, use the NODE_NAME to generate a unique value between 0 and 254
THIRD_OCTET=$(printf "%d" "'$NODE_NAME" | awk '{print $1 % 255}')



# Multus
CNI_PLUGINS_VERSION="v1.5.1"
CNI_PLUGINS=("bridge" "loopback" "host-device" "macvlan")

if [ $ARCHITECTURE == "x86_64" ]; then
    echo "Detected a $ARCHITECTURE, by default the host interface is considered to be ens18"
    HOST_INTERFACE="ens18" # Change this to the name of the host interface
elif [ $ARCHITECTURE == "aarch64" ]; then
    echo "Detected a non-NXP S32G platform, $ARCHITECTURE, by default the host interface is considered to be eth0"
    HOST_INTERFACE="eth0" # Change this to the name of the host interface
    NXP_S32=1

else
    echo "Unsupported platform, $ARCHITECTURE"
    return 1
fi



# validate the commandline arguments and variables

# the first, second and third octet are a number between 0 and 255
if [[ ! "$FIRST_OCTET" =~ ^[0-9]+$ ]] || [[ ! "$SECOND_OCTET" =~ ^[0-9]+$ ]] || [[ ! "$THIRD_OCTET" =~ ^[0-9]+$ ]]; then
    echo "Error: The first, second and third octet must be a number between 0 and 255"
    return 1
fi

# ENABLE_LOCAL_DISCOVERY must be a boolean
if [[ "$ENABLE_LOCAL_DISCOVERY" != "true" && "$ENABLE_LOCAL_DISCOVERY" != "false" ]]; then
    echo "Error: ENABLE_LOCAL_DISCOVERY must be either 'true' or 'false'"
    return 1
fi

# INTERFACE must be a valid network interface present on the machine
if ! ip a | grep -q $HOST_INTERFACE; then
    echo "Error: INTERFACE is not a valid network interface"
    return 1
fi

NODE_IP=$(ip a | grep $HOST_INTERFACE | grep inet | awk '{print $2}' | cut -d '/' -f 1)

# NODE_IP must be a valid IP address
if ! [[ "$NODE_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Error: NODE_IP on interface $HOST_INTERFACE is not a valid IP address: $NODE_IP"
    return 1
fi

# Convert to lowercase and remove special characters to make the string compatible with Liqo
clean_string(){
    echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_-]//g'
}


NODE_NAME=$(clean_string "$NODE_NAME") # you can change this to a custom name, but ensure it is lowercase and without special characters
echo "Environment has been correctly set up"

