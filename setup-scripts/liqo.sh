#!/bin/bash

liqo() {
    if [ "$1" == "install" ]; then
        echo "Installing Liqo"
        curl -s --fail -LS "https://github.com/liqotech/liqo/releases/download/$LIQOCTL_VERSION/liqoctl-linux-amd64.tar.gz" | tar -xz
        sudo install -o root -g root -m 0755 liqoctl /usr/local/bin/liqoctl
        rm -f liqoctl LICENSE
        liqoctl install k3s --timeout 10m --cluster-name "$NODE_NAME"
        kubectl wait --for=condition=ready pod -n liqo --all --timeout=300s
        # Add liqoctl completion to .bashrc if it's not already present
        if ! grep -qxF 'source <(liqoctl completion bash)' "$USER_HOME/.bashrc"; then
            echo 'source <(liqoctl completion bash)' >> "$USER_HOME/.bashrc"
        fi
    elif [ "$1" == "uninstall" ]; then
        echo "Uninstalling Liqo"
        liqoctl uninstall --skip-confirm
    else
        echo "Usage: liqo {install|uninstall}"
        exit 1
    fi
}