#!/bin/bash

multus() {
    if [ "$1" == "install" ]; then
        echo "Installing Multus"
        helm repo add rke2-charts https://rke2-charts.rancher.io
        helm repo update
        kubectl apply -f - <<EOF
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  name: multus
  namespace: kube-system
spec:
  repo: https://rke2-charts.rancher.io
  chart: rke2-multus
  targetNamespace: kube-system
  valuesContent: |-
    config:
      fullnameOverride: multus
      cni_conf:
        confDir: /var/lib/rancher/k3s/agent/etc/cni/net.d
        binDir: /var/lib/rancher/k3s/data/cni/
        kubeconfig: /var/lib/rancher/k3s/agent/etc/cni/net.d/multus.d/multus.kubeconfig
EOF
        kubectl wait --for=condition=ready pod -n kube-system -l app=rke2-multus --timeout=90s
    elif [ "$1" == "uninstall" ]; then
        echo "Uninstalling Multus"
        helm uninstall multus -n kube-system
    else
        echo "Usage: multus {install|uninstall}"
        exit 1
    fi
}