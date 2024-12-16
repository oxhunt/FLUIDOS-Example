#!/bin/bash

# Get all namespaced resource types
resources=$(kubectl api-resources --verbs=list --namespaced -o name)

# Namespace to query
namespace="fluidos"

resources_to_exclude="events.events.k8s.io issuers.cert-manager.io certificates.cert-manager.io events"

# filter the resources to exclude the ones in the "resources_to_exclude" variable
resources=$(echo "$resources" | grep -v "$resources_to_exclude")

# Loop through each resource type and get the resources in the specified namespace
for resource in $resources; do
  # Get the resources and check if any exist
  output=$(kubectl get "$resource" -n "$namespace" 2>/dev/null)
  if [ -n "$output" ]; then
    echo "Resource: $resource"
    echo "$output"
    echo ""
  fi
done