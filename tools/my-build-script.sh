#!/bin/bash

# Set up buildx builder, it's needed only once
# docker buildx create --use


# Takes one or more arguments that specify the containers to build

containers=(camera-streamer image-recognition fl-orchestrator inspection-container)

# if no arguments are provided, build all containers
if [ $# -eq 0 ]; then
    echo "No containers specified, building all containers"
    to_build=${containers[@]}
else
    to_build=($@)
fi

# check that all containers to build are valid
for container in ${to_build[@]}; do
    if [[ ! " ${containers[@]} " =~ " ${container} " ]]; then
        echo "Invalid container name: $container"
        echo "Valid containers are: ${containers[@]}"
        return 1
    fi
done


for container in ${to_build[@]}; do
    echo "Building container: $container"
    docker buildx build --platform linux/amd64,linux/arm64 -t oxhunt/$container:latest ../containers/$container --push
done
# Build and push multi-arch images
#docker buildx build --platform linux/amd64,linux/arm64 -t oxhunt/camera-streamer:latest ../containers/camera-streamer --push
#docker buildx build --platform linux/amd64,linux/arm64 -t oxhunt/image-recognition:latest ../containers/image-recognition --push
#docker buildx build --platform linux/amd64,linux/arm64 -t oxhunt/fl-orchestrator:latest ../containers/fl-orchestrator --push
#docker buildx build --platform linux/amd64,linux/arm64 -t oxhunt/inspection-container:latest ../containers/inspection-container --push


#docker buildx build --platform linux/amd64,linux/arm64 -t oxhunt/kc-provider:latest ../containers/kuksa-can-provider --push

