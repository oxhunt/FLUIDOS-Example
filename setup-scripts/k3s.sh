#!/bin/bash

k3ssh() {
    if [ "$1" == "install" ]; then
        echo "Installing K3s"
        curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--disable=servicelb" K3S_KUBECONFIG_MODE="644" sh -
        export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
        kubectl wait --for=condition=ready pod -n kube-system --all --timeout=90s
        wget "https://github.com/derailed/k9s/releases/download/$K9S_VERSION/k9s_linux_amd64.deb"
        sudo apt install ./k9s_linux_amd64.deb
        sudo rm k9s_linux_amd64.deb
        
        # Add KUBECONFIG to .bashrc if it's not already present
        grep -qxF 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' "$USER_HOME/.bashrc" || echo 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' >> ~/.bashrc

        # Add alias for kubectl to .bashrc only if it's not already present
        grep -qxF 'alias k=kubectl' "$USER_HOME/.bashrc" || echo 'alias k=kubectl' >> "$USER_HOME/.bashrc"

        # Add kubectl bash completion sourcing to .bashrc only if it's not already present
        grep -qxF 'source <(kubectl completion bash)' "$USER_HOME/.bashrc" || echo 'source <(kubectl completion bash)' >> "$USER_HOME/.bashrc"

        # Add kubectl completion for the alias 'k' only to .bashrc if it's not already present
        grep -qxF 'complete -F __start_kubectl k' "$USER_HOME/.bashrc" || echo 'complete -F __start_kubectl k' >> "$USER_HOME/.bashrc"
    
        kubectl config set-context --current --editor "nano" &>/dev/null

    elif [ "$1" == "uninstall" ]; then
        echo "Uninstalling K3s"
        /usr/local/bin/k3s-uninstall.sh
        sudo apt remove k9s -y
    else
        echo "Usage: k3s {install|uninstall}"
        return 1
    fi
}