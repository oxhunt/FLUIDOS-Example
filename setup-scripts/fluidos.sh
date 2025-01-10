#!/bin/bash

fluidos() {
    if [ "$1" == "install" ]; then
        # Labels to add to the nodes
        declare -A LABELS
        LABELS["node-role.fluidos.eu/worker"]="true"
        LABELS["node-role.fluidos.eu/resources"]="true"


        # Label the node
        echo "  - Labeling the node"
        for LABEL_KEY in "${!LABELS[@]}"; do
            LABEL_VALUE=${LABELS[$LABEL_KEY]}
            kubectl label node "$NODE_NAME" "$LABEL_KEY=$LABEL_VALUE" --overwrite
            echo "Label $LABEL_KEY=$LABEL_VALUE set on node $NODE_NAME"
        done
        echo "Installing FLUIDOS"
        helm repo add fluidos https://fluidos-project.github.io/node/
        helm repo update
        curl -s -o consumer-values.yaml https://raw.githubusercontent.com/fluidos-project/node/main/quickstart/utils/consumer-values.yaml
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
            --wait
        rm -f consumer-values.yaml
    elif [ "$1" == "uninstall" ]; then
        echo "Uninstalling FLUIDOS"
        helm delete node -n fluidos
        kubectl delete namespace fluidos
        kubectl get crd | grep fluidos.eu | awk '{print $1}' | xargs kubectl delete crd
    else
        echo "Usage: fluidos {install|uninstall}"
        exit 1
    fi
}