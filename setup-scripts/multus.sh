#!/bin/bash

multus() {
    if [ "$1" == "install" ]; then
        echo "Installing Multus"
        helm repo add rke2-charts https://rke2-charts.rancher.io
        helm repo update
#        kubectl apply -f - <<EOF
#apiVersion: helm.cattle.io/v1
#kind: HelmChart
#metadata:
#  name: multus
#  namespace: kube-system
#spec:
#  repo: https://rke2-charts.rancher.io
#  chart: rke2-multus
#  targetNamespace: kube-system
#  valuesContent: |-
#    config:
#      fullnameOverride: multus
#      cni_conf:
#        confDir: /var/lib/rancher/k3s/agent/etc/cni/net.d
#        binDir: $CNI_BIN_DIR
#        kubeconfig: /var/lib/rancher/k3s/agent/etc/cni/net.d/multus.d/multus.kubeconfig
#EOF
        
# This should be the same as the above

        helm install multus rke2-charts/rke2-multus --namespace kube-system --create-namespace \
              --set config.fullnameOverride=multus \
              --set config.cni_conf.confDir=/var/lib/rancher/k3s/agent/etc/cni/net.d/ \
              --set config.cni_conf.binDir=/var/lib/rancher/k3s/data/current/bin/ \
              --set config.cni_conf.kubeconfig=/var/lib/rancher/k3s/agent/etc/cni/net.d/multus.d/multus.kubeconfig \
              #--set config.cni_conf.multusConfFile=/etc/rancher/k3s/k3s.yaml
              #--set config.cni_conf.binDir=/var/lib/rancher/k3s/data/cni/  # for k3s version > 1.28.15

        # Wait for Multus to be running
        echo "Waiting for Multus to be running..."
        # wait for multus to be ready
        while ! kubectl get pod -n kube-system -l app=rke2-multus | grep -v grep >/dev/null; do
            sleep 5
        done
        echo "Multus is running"

        echo "Waiting for Multus to be ready..."
        # Check if Multus is running
        kubectl wait --for=condition=ready pod -n kube-system -l app=rke2-multus --timeout=90s
    elif [ "$1" == "uninstall" ]; then
        echo "Uninstalling Multus"
        helm uninstall multus -n kube-system
        kubectl delete crd network-attachment-definitions.k8s.cni.cncf.io | grep -v "No multus crds found, skipping"
        #kubectl delete helmchart.helm.cattle.io/multus -n kube-system
    else
        echo "Usage: multus {install|uninstall}"
        return 1
    fi
}
