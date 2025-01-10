#!/bin/bash

metallb() {
    if [ "$1" == "install" ]; then
        echo "Installing MetalLB"
        helm repo add metallb https://metallb.github.io/metallb
        helm repo update
        helm install metallb metallb/metallb --namespace metallb-system --create-namespace
        kubectl wait --namespace metallb-system --for=condition=available deployment --selector=app.kubernetes.io/name=metallb --timeout=300s
        cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
    name: default
    namespace: metallb-system
spec:
    addresses:
        - $NODE_IP-$NODE_IP
EOF
        cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
    name: default
    namespace: metallb-system
EOF
    elif [ "$1" == "uninstall" ]; then
        echo "Uninstalling MetalLB"
        helm uninstall metallb --namespace metallb-system
    else
        echo "Usage: metallb {install|uninstall}"
        exit 1
    fi
}