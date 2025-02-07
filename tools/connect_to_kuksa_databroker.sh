#!/bin/bash
#docker run -it --network host --rm ghcr.io/eclipse-kuksa/kuksa-databroker-cli:main --server Server:55555
kubectl run kuksa-databroker-cli --rm -i --tty --image=ghcr.io/eclipse-kuksa/kuksa-databroker-cli:main -- --server kuksa-databroker:55555