#!/bin/bash

# Set up buildx builder
docker buildx create --use

# Build and push multi-arch images
docker buildx build --platform linux/amd64,linux/arm64 -t oxhunt/camera-streamer:latest ../containers/camera-streamer --push
docker buildx build --platform linux/amd64,linux/arm64 -t oxhunt/image-recognition:latest ../containers/image-recognition --push

