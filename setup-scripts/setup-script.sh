#!/bin/bash

# This script installs the required components to run FLUIDOS on a K3s cluster.
# if you use this script, make sure that the ip address of the machine does not change or it could break the metallb configuration

NODE_NAME=$(hostname)
HOST_INTERFACE="ens18" # Change this to the name of the host interface
LIQOCTL_VERSION="v0.10.0"
FLUIDOS_VERSION="0.1.1"
NODE_IP=$(ip a | grep $HOST_INTERFACE | grep inet | awk '{print $2}' | cut -d '/' -f 1)
REAR_PORT=30000


# loadbalancer config
METALLB_ADDRESS_POOL_NAME="default"

# Network Manager
ENABLE_LOCAL_DISCOVERY=true
FIRST_OCTET=10 # Change this to the first octet of the IP address range of the pod cidr
SECOND_OCTET=42 # Change this to the second octet of the IP address range of the pod cidr
THIRD_OCTET=1 # Change this to the third octet of the IP address range of the pod cidr



# Multus
CNI_PLUGINS_VERSION="v1.5.1"
CNI_PLUGINS=("bridge" "loopback" "host-device" "macvlan")

# check that a commandline argument is received
if [ $# -lt 1 ]; then
    echo "Usage: $0 "install" or "uninstall""
    exit 1
fi

if [ "$1" == "uninstall" ]; then
    # Export the KUBECONFIG
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

    # warn the user that the script will uninstall fluidos, and ask it for confirmation before proceeding, by default it will uninstall
    read -p "This script will uninstall FLUIDOS Do you want to proceed? (Y/n) " -n 1 -r

    if [[ $REPLY =~ ^[Nn]$ ]]; then
        echo "Uninstall aborted"
        exit 0
    fi

    # Uninstall FLUIDOS
    echo "  - Uninstalling FLUIDOS"
    helm delete node -n fluidos --debug --v=2 --wait 1>/dev/null
    kubectl delete namespace fluidos 1>/dev/null
    kubectl get crd | grep fluidos.eu | awk '{print $1}' | xargs kubectl delete crd 1>/dev/null

    if [ $? -ne 0 ]; then
        echo "Error: Failed to uninstall FLUIDOS"
        exit 1
    fi

    echo "FLUIDOS Uninstall complete"

    # warn the user that the script will uninstall fluidos, and ask it for confirmation before proceeding, by default it will uninstall
    read -p "This script will uninstall Liqo Do you want to proceed? (Y/n) " -n 1 -r

    if [[ $REPLY =~ ^[Nn]$ ]]; then
        echo "Uninstall aborted"
        exit 0
    fi

    # Uninstall Liqo
    if command -v liqoctl &>/dev/null; then
        LIQO_STATUS=$(liqoctl status 2>/dev/null)

        # Check if the status is not empty
        if [ -n "$LIQO_STATUS" ]; then
            echo "  - Uninstall Liqo"
            liqoctl uninstall --skip-confirm
            if [ $? -ne 0 ]; then
                echo "Error: Failed to uninstall Liqo"
                exit 1
            fi
        else
            echo "Liqo is not installed on this cluster."
        fi
    else
        echo "liqoctl command not found. Cannot uninstall."
    fi

    echo "Liqo Uninstall complete"


    # warn the user that the script will uninstall fluidos, and ask it for confirmation before proceeding, by default it will uninstall
    read -p "This script will uninstall K3s Do you want to proceed? (Y/n) " -n 1 -r

    if [[ $REPLY =~ ^[Nn]$ ]]; then
        echo "Uninstall aborted"
        exit 0
    fi

    # Uninstall MetalLB
    if helm list -A | grep -q metallb; then
        echo "  - Uninstall MetalLB"
        helm uninstall metallb --namespace metallb-system &>/dev/null
    fi

    # Uninstall Multus
    if kubectl get daemonset -n kube-system multus &>/dev/null; then
        echo "  - Uninstall Multus"
        helm uninstall multus -n kube-system &>/dev/null
    fi

    # Uninstall K3s
    echo "  - Uninstall K3s"
    /usr/local/bin/k3s-uninstall.sh &>/dev/null

    echo "Uninstall complete"
    exit 0
elif [ "$1" != "install" ]; then
    echo "Usage: $0 "install" or "uninstall""
    exit 1
fi


# Update the package list
sudo apt update &>/dev/null

# Install the required packages
sudo apt install -y curl gpg &>/dev/null
curl -s https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
sudo apt install apt-transport-https --yes &>/dev/null
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list &>/dev/null

# Update the package list again
sudo apt update &>/dev/null

# Install Helm
sudo apt install -y helm &>/dev/null

# disable firewall to avoid problems down the road, we don't need security right now
sudo ufw disable &>/dev/null

# if k3s is already installed, ask the user if they want to reinstall it
if command -v k3s &>/dev/null; then
    read -p "K3s is already installed. Do you want to reinstall it? (Y/n) " -n 1 -r

    if [[ $REPLY =~ ^[Nn]$ ]]; then
        echo "\nSkipping"
    else

        # install k3s without the included loadbalancer, we use metallb instead
        curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--disable=servicelb" K3S_KUBECONFIG_MODE="644" sh - &>/dev/null


        export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

        # Add KUBECONFIG to .bashrc if it's not already present
        grep -qxF 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' ~/.bashrc || echo 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' >> ~/.bashrc

        # Add alias for kubectl to .bashrc only if it's not already present
        grep -qxF 'alias k=kubectl' ~/.bashrc || echo 'alias k=kubectl' >> ~/.bashrc

        # Add kubectl bash completion sourcing to .bashrc only if it's not already present
        grep -qxF 'source <(kubectl completion bash)' ~/.bashrc || echo 'source <(kubectl completion bash)' >> ~/.bashrc

        # Add kubectl completion for the alias 'k' only to .bashrc if it's not already present
        grep -qxF 'complete -F __start_kubectl k' ~/.bashrc || echo 'complete -F __start_kubectl k' >> ~/.bashrc

        # Wait until resources are available in the kube-system namespace
        while true; do
            pod_count=$(kubectl get pods -n kube-system --no-headers 2>/dev/null | wc -l)
            if [ "$pod_count" -gt 0 ]; then
                echo "Resources found in kube-system namespace."
                break
            else
                echo "Waiting for resources to appear in kube-system namespace..."
                sleep 5
            fi
        done

        # Wait for all pods to become ready
        kubectl wait --for=condition=ready pod -n kube-system --all --timeout=90s &>/dev/null



        # The latest version of FLUIDOS Node manager requires Multus
        echo "Install Multus"

        helm repo add rke2-charts https://rke2-charts.rancher.io &>/dev/null
        helm repo update &>/dev/null

        # Apply Multus HelmChart directly
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
        # Wait until Multus resources are available in the kube-system namespace
        while true; do
            multus_pod_count=$(kubectl get pods -n kube-system -l app=rke2-multus --no-headers 2>/dev/null | wc -l)
            if [ "$multus_pod_count" -gt 0 ]; then
                echo "Multus pods found in kube-system namespace."
                break
            else
                echo "Waiting for Multus pods to appear in kube-system namespace..."
                sleep 5
            fi
        done

        # Wait for all Multus pods to become ready
        kubectl wait --for=condition=ready pod -n kube-system -l app=rke2-multus --timeout=90s &>/dev/null

        echo "  - Patch Multus DaemonSet to remove CPU and memory limits"
        # Patch the Multus DaemonSet to remove CPU and memory limits
        kubectl patch daemonset -n kube-system multus --type=json -p='[
    {
        "op": "remove",
        "path": "/spec/template/spec/containers/0/resources/limits/cpu"
    },
    {
        "op": "remove",
        "path": "/spec/template/spec/containers/0/resources/limits/memory"
    }
]' &>/dev/null

        # Wait until Multus resources are available in the kube-system namespace
        while true; do
            multus_pod_count=$(kubectl get pods -n kube-system -l app=rke2-multus --no-headers 2>/dev/null | wc -l)
            if [ "$multus_pod_count" -gt 0 ]; then
                echo "Multus pods found in kube-system namespace."
                break
            else
                echo "Waiting for Multus pods to appear in kube-system namespace..."
                sleep 5
            fi
        done

        # Wait for all Multus pods to become ready
        kubectl wait --for=condition=ready pod -n kube-system -l app=rke2-multus --timeout=90s &>/dev/null

        echo "  - Install CNI plugins"

        # Create the CNI bin directory if it doesn't exist
        sudo mkdir -p /opt/cni/bin/ &>/dev/null
        sudo mkdir -p /var/lib/rancher/k3s/data/cni &>/dev/null

        # Download the latest version of the CNI plugins
        curl -s -L "https://github.com/containernetworking/plugins/releases/download/${CNI_PLUGINS_VERSION}/cni-plugins-linux-amd64-${CNI_PLUGINS_VERSION}.tgz" -o /tmp/cni-plugins.tgz

        # Extract the CNI plugins temporarily
        mkdir -p /tmp/cni-plugins &>/dev/null
        tar -xzvf /tmp/cni-plugins.tgz -C /tmp/cni-plugins/ &>/dev/null

        # Move only the required plugins to /opt/cni/bin/
        for plugin in "${CNI_PLUGINS[@]}"; do
            sudo cp /tmp/cni-plugins/$plugin /opt/cni/bin/
            sudo cp /tmp/cni-plugins/$plugin /var/lib/rancher/k3s/data/cni
        done

        # Clean up the temporary files
        rm -rf /tmp/cni-plugins &>/dev/null
        rm /tmp/cni-plugins.tgz &>/dev/null

        # Patch Multus DaemonSet to not schedule on Liqo nodes
        kubectl patch daemonset multus -n kube-system --type='json' -p='[{"op": "add", "path": "/spec/template/spec/affinity", "value": {"nodeAffinity": {"requiredDuringSchedulingIgnoredDuringExecution": {"nodeSelectorTerms": [{"matchExpressions": [{"key": "liqo.io/type", "operator": "DoesNotExist"}]}]}}}}]' &>/dev/null
        # Rollout the Multus DaemonSet
        kubectl rollout restart daemonset multus -n kube-system &>/dev/null

        # Wait until Multus resources are available in the kube-system namespace
        while true; do
            multus_pod_count=$(kubectl get pods -n kube-system -l app=rke2-multus --no-headers 2>/dev/null | wc -l)
            if [ "$multus_pod_count" -gt 0 ]; then
                echo "Multus pods found in kube-system namespace."
                break
            else
                echo "Waiting for Multus pods to appear in kube-system namespace..."
                sleep 5
            fi
        done

        # Wait for all Multus pods to become ready
        kubectl wait --for=condition=ready pod -n kube-system -l app=rke2-multus --timeout=90s &>/dev/null


        echo "Install MetalLB"

        # Export the KUBECONFIG
        export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

        # Add the MetalLB Helm repository
        helm repo add metallb https://metallb.github.io/metallb &>/dev/null
        helm repo update &>/dev/null

        # Create metallb-memberlist secret
        #kubectl create secret generic metallb-memberlist \
        #    --from-literal=secretkey="$(openssl rand -base64 128)" \
        #    -n metallb-system

        # Install MetalLB with Helm
        echo "  - Install MetalLB with Helm"
        helm install metallb metallb/metallb --namespace metallb-system --create-namespace &>/dev/null

        # Wait until MetalLB deployments are available in the metallb-system namespace
        while true; do
            metallb_deployment_count=$(kubectl get deployments -n metallb-system -l app.kubernetes.io/name=metallb --no-headers 2>/dev/null | wc -l)
            if [ "$metallb_deployment_count" -gt 0 ]; then
                echo "MetalLB deployments found in metallb-system namespace."
                break
            else
                echo "Waiting for MetalLB deployments to appear in metallb-system namespace..."
                sleep 5
            fi
        done

        # Wait for MetalLB deployments to become available
        kubectl wait --namespace metallb-system --for=condition=available deployment --selector=app.kubernetes.io/name=metallb --timeout=300s &>/dev/null

        # Configure MetalLB
        echo "  - Configure MetalLB"
        # Setup address pool used by loadbalancers
        cat <<EOF | kubectl apply -f - > /dev/null
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
    name: $METALLB_ADDRESS_POOL_NAME
    namespace: metallb-system
spec:
    addresses:
        - $NODE_IP-$NODE_IP
EOF

    cat <<EOF | kubectl apply -f - > /dev/null
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
    name: $METALLB_ADDRESS_POOL_NAME
    namespace: metallb-system
EOF


        # wait for the metallb controller to be ready
        kubectl wait --namespace metallb-system --for=condition=available deployment --selector=app.kubernetes.io/name=controller --timeout=300s &>/dev/null

        echo "metallb installed and configured"
    fi
fi

# if liqo seems to be already installed, ask the user if they want to reinstall it
if command -v liqoctl status &>/dev/null; then
    LIQO_STATUS=$(liqoctl status 2>/dev/null)

    # Check if the status is not empty
    if [ -n "$LIQO_STATUS" ]; then
        read -p "Liqo is already installed. Do you want to reinstall it? (Y/n) " -n 1 -r

        if [[ $REPLY =~ ^[Nn]$ ]]; then
            echo "\nSkipping"
        fi
    else

        echo "Install Liqo"

        # Export the KUBECONFIG
        export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

        # Install liqoctl
        echo "  - Install liqoctl"
        curl -s --fail -LS "https://github.com/liqotech/liqo/releases/download/$LIQOCTL_VERSION/liqoctl-linux-amd64.tar.gz" | tar -xz
        if [ $? -ne 0 ]; then
            echo "Error: Failed to download liqoctl"
            exit 1
        fi
        sudo install -o root -g root -m 0755 liqoctl /usr/local/bin/liqoctl 2>/dev/null
        if [ $? -ne 0 ]; then
            echo "Error: Failed to install liqoctl"
            exit 1
        fi

        # Clean up the temporary files
        rm -f liqoctl 2>/dev/null
        rm -f LICENSE 2>/dev/null

        # Add liqoctl completion to .bashrc if it's not already present
        if ! grep -qxF 'source <(liqoctl completion bash)' ~/.bashrc; then
            echo 'source <(liqoctl completion bash)' >> ~/.bashrc
        fi

        # Install Liqo
        echo "  - Install Liqo"
        liqoctl install k3s --timeout 10m --cluster-name "$NODE_NAME"
        if [ $? -ne 0 ]; then
            echo "Error: Failed to install Liqo"
            exit 1
        fi


        echo "Liqo installed"

        # wait for the liqo pods to be ready
        kubectl wait --for=condition=ready pod -n liqo --all --timeout=300s &>/dev/null
    fi
fi



# if fluidos seems to be already installed, ask the user if they want to reinstall it
if helm list -A | grep -q fluidos; then
    read -p "FLUIDOS is already installed. Do you want to reinstall it? (Y/n) " -n 1 -r

    if [[ $REPLY =~ ^[Nn]$ ]]; then
        echo "\nSkipping"
        exit 0
    fi
fi

# Labels to add to the nodes
declare -A LABELS
LABELS["node-role.fluidos.eu/worker"]="true"
LABELS["node-role.fluidos.eu/resources"]="true"


echo "Install Fluidos"

# Export the KUBECONFIG
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# Add the FLUIDOS Helm repository
echo "  - Checking if FLUIDOS Helm repository is already present"
if helm repo list | grep -q "^fluidos"; then
    echo "  - FLUIDOS Helm repository is already added"
else
    echo "  - Adding FLUIDOS Helm repository"
    helm repo add fluidos https://fluidos-project.github.io/node/ 1>/dev/null
    helm repo update 1>/dev/null
    if [ $? -ne 0 ]; then
        echo "Error: Failed to add or update the FLUIDOS Helm repository"
        exit 1
    fi
fi

# Download 'consumer-values.yaml' file from GitHub
echo "  - Downloading consumer-values.yaml"
curl -s -o consumer-values.yaml https://raw.githubusercontent.com/fluidos-project/node/main/quickstart/utils/consumer-values.yaml
if [ $? -ne 0 ]; then
    echo "Error: Failed to download consumer-values.yaml"
    exit 1
fi

# replacing the interface in the consumer-values.yaml file
#sed -i "s/netInterface: \"eth0\"/netInterface: \"$HOST_INTERFACE\"/" consumer-values.yaml

# Label the node
echo "  - Labeling the node"
for LABEL_KEY in "${!LABELS[@]}"; do
    LABEL_VALUE=${LABELS[$LABEL_KEY]}
    kubectl label node "$NODE_NAME" "$LABEL_KEY=$LABEL_VALUE" --overwrite
    echo "Label $LABEL_KEY=$LABEL_VALUE set on node $NODE_NAME"
done

# Install FLUIDOS
echo "  - Installing FLUIDOS"
helm upgrade --install node fluidos/node \
    -n fluidos --version "$FLUIDOS_VERSION" \
    --create-namespace -f consumer-values.yaml \
    --set networkManager.configMaps.nodeIdentity.ip="$NODE_IP" \
    --set rearController.service.gateway.nodePort.port="$REAR_PORT" \
    --set networkManager.config.enableLocalDiscovery="$ENABLE_LOCAL_DISCOVERY" \
    --set networkManager.config.address.firstOctet="$FIRST_OCTET" \
    --set networkManager.config.address.secondOctet="$SECOND_OCTET" \
    --set networkManager.config.address.thirdOctet="$THIRD_OCTET" \
    --set networkManager.config.netInterface="$HOST_INTERFACE" \
    --wait \
    --debug \
    --v=2 \
    1>/dev/null

if [ $? -ne 0 ]; then
    echo "Error: Failed to install FLUIDOS"
    exit 1
fi

# Remove the 'consumer-values.yaml' file
rm -f consumer-values.yaml 2>/dev/null



## OLD WORKAROUND: The FLUIDOS Helm chart currently uses the 'eth0' interface as the master interface for the Macvlan CNI, future versions will allow the user to specify the master interface in the helm chart. 
## This workaround modifies the Macvlan CNI configuration to use the correct master interface.
## if you don't do this, the networkmanager will remain stuck in ContainerCreating state
#
## Export the YAML to a file
#kubectl get network-attachment-definitions.k8s.cni.cncf.io macvlan-conf -n fluidos -o yaml > macvlan-conf.yaml
#
## Modify eth0 to the value of $HOST_INTERFACE in the file
#sed -i "s/\"master\": \"eth0\"/\"master\": \"$HOST_INTERFACE\"/" macvlan-conf.yaml
#
## Apply the modified YAML back to the cluster
#kubectl apply -f macvlan-conf.yaml
#
## Clean up the temporary file
#rm -f macvlan-conf.yaml