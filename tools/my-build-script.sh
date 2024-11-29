#!/bin/bash

# commands I've put here for reference, I have used them to build and push the images to my dockerhub

docker build -t oxhunt/camera-streamer:latest ../containers/camera-streamer
docker push oxhunt/camera-streamer:latest

docker build -t oxhunt/image-recognition:latest ../containers/image-recognition
docker push oxhunt/image-recognition:latest

kubectl delete -f ../k8s_manifests
sleep 20
kubectl apply -f ../k8s_manifests

kubectl get pods --watch