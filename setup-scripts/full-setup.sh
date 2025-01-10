#!/bin/bash
# Load component scripts
source ./env.sh
source ./k3s.sh
source ./multus.sh
source ./metallb.sh
source ./liqo.sh
source ./fluidos.sh

# Main installation logic
if [ "$1" == "install" ]; then
    ./install_requirements.sh
    k3s install
    multus install
    metallb install
    liqo install
    fluidos install
elif [ "$1" == "uninstall" ]; then
    fluidos uninstall
    liqo uninstall
    metallb uninstall
    multus uninstall
    k3s uninstall
else
    echo "Usage: $0 {install|uninstall}"
    exit 1
fi