#!/bin/bash

prometheus() {
    if [ "$1" == "install" ]; then
        kubectl create namespace monitoring
        helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
        helm repo update
        helm upgrade --install --namespace monitoring prometheus prometheus-community/prometheus \
            --set server.service.type=NodePort \
            --set server.service.nodePort=30090 \
            --set server.global.scrape_interval=1s \
            --set server.global.scrape_timeout=1s \
            --set server.retention=3h # decreasing retention from 15d to avoid overloading the ram and disk
            #--set server.global.evaluationInterval=10s
    elif [ "$1" == "uninstall" ]; then
        echo "Uninstalling Multus"
        helm uninstall --namespace monitoring prometheus
        kubectl delete namespace monitoring
    else
        echo "Usage: $0 {install|uninstall}"
        return 1
    fi
}
