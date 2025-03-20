#!/bin/bash
# Load component scripts
source ./env.sh
source ./k3s.sh
source ./multus.sh
source ./metallb.sh
source ./liqo.sh
source ./fluidos.sh
source ./prometheus.sh

echo "Sourcing phase completed, installing components..."

# Main installation logic
if [ "$1" == "install" ]; then
    if [ "$NXP_S32" == 1 ]; then
        echo "Running on a NXP S32G platform, $ARCHITECTURE"
        echo "WARNING: The NXP S32G platform is not fully supported yet, expect bugs"
        k3s_bashrc_setup
    else
        echo "Running on a non-NXP S32G platform: $ARCHITECTURE"
        ./install_requirements.sh
        k3ssh install
    fi
    multus install
    metallb install
    liqo install
    fluidos install
    prometheus install
elif [ "$1" == "uninstall" ]; then
    prometheus uninstall
    fluidos uninstall
    liqo uninstall
    metallb uninstall
    multus uninstall
    if [ "$NXP_S32" == 0 ]; then
        k3ssh uninstall
    else
        echo "skipping k3s uninstall on NXP S32G platform"
    fi
    
else
    echo "Usage: $0 {install|uninstall}"
fi