#!/bin/bash
# Load component scripts
source ./env.sh
source ./k3s.sh
source ./multus.sh
source ./metallb.sh
source ./liqo.sh
source ./fluidos.sh
source ./prometheus.sh

# Main installation logic
if [ "$1" == "install" ]; then
    ./install_requirements.sh
    k3ssh install
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
    k3ssh uninstall
else
    echo "Usage: $0 {install|uninstall}"
    return 1
fi