#!/bin/bash

prometheus() {
    if [ "$1" == "install" ]; then
        kubectl create namespace monitoring
        helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
        helm repo update
        helm install --namespace monitoring prometheus prometheus-community/prometheus
    elif [ "$1" == "uninstall" ]; then
        echo "Uninstalling Multus"
        helm uninstall --namespace monitoring prometheus
        kubectl delete namespace monitoring
    fi
}
