#!/bin/bash

prometheus() {
    if [ "$1" == "install" ]; then
        kubectl create namespace monitoring
        helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
        helm repo update
        helm upgrade --install --namespace monitoring prometheus prometheus-community/prometheus \
            --set server.service.type=NodePort \
            --set server.service.nodePort=30090 \
            --set server.global.scrape_interval=5s \
            --set server.global.scrape_timeout=3s \
            --set server.retentionSize=1GB \
            --set server.retention=1h 
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
