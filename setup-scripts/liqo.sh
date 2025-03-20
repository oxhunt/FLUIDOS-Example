#!/bin/bash

liqo() {
    if [ "$1" == "install" ]; then
        echo "Installing Liqo"
        curl -s --fail -LS "https://github.com/liqotech/liqo/releases/download/$LIQOCTL_VERSION/liqoctl-linux-amd64.tar.gz" | tar -xz
        sudo install -o root -g root -m 0755 liqoctl /usr/local/bin/liqoctl
        rm -f liqoctl LICENSE
        liqoctl install k3s --timeout 10m --cluster-name "$NODE_NAME" --verbose --pod-cidr "$(kubectl get nodes -o jsonpath='{.items[*].spec.podCIDR}')" --service-cidr "$(echo '{"apiVersion":"v1","kind":"Service","metadata":{"name":"tst"},"spec":{"clusterIP":"1.1.1.1","ports":[{"port":443}]}}' | kubectl apply -f - 2>&1 | sed 's/.*valid IPs is //')"
        kubectl wait --for=condition=ready pod -n liqo --all --timeout=300s
        # Add liqoctl completion to .bashrc if it's not already present
        if ! grep -qxF 'source <(liqoctl completion bash)' "$USER_HOME/.bashrc"; then
            echo 'source <(liqoctl completion bash)' >> "$USER_HOME/.bashrc"
        fi
    elif [ "$1" == "uninstall" ]; then
        echo "Uninstalling Liqo"

        timeout 10 bash -c 'kubectl get crd | grep liqo | awk "{print \$1}" | xargs kubectl delete crd'

        kubectl get crd | grep liqo | awk '{print $1}' | while read -r crd; do
            kubectl patch crd "$crd" -p '{"metadata":{"finalizers":[]}}' --type=merge
        done

        kubectl delete svc --all -n liqo

        kubectl delete deploy --all -n liqo

        kubectl delete daemonset --all -n liqo

        kubectl delete pod --all -n liqo

        kubectl delete -n liqo cronjob.batch/liqo-telemetry

        kubectl delete -n liqo job.batch/liqo-pre-delete

        timeout 5 bash -c '
        kubectl get ns | grep liqo | awk "{print \$1}" | while read -r namespace; do
            kubectl delete namespace "$namespace"
        done
        '

        kubectl get ns | grep liqo | awk '{print $1}' | while read -r namespace; do
            kubectl get namespace "$namespace" -o json \
            | tr -d "\n" | sed "s/\"finalizers\": \[[^]]\+\]/\"finalizers\": []/" \
            | kubectl replace --raw "/api/v1/namespaces/$namespace/finalize" -f -
        done

        kubectl get clusterrole | grep liqo | awk '{print $1}' | xargs kubectl delete clusterrole

        kubectl get clusterrolebinding | grep liqo | awk '{print $1}' | xargs kubectl delete clusterrolebinding

        kubectl get mutatingwebhookconfiguration | grep liqo | awk '{print $1}' | xargs kubectl delete mutatingwebhookconfiguration
        kubectl get validatingwebhookconfiguration | grep liqo | awk '{print $1}' | xargs kubectl delete validatingwebhookconfiguration

    else
        echo "Usage: liqo {install|uninstall}"
        return 1
    fi
}