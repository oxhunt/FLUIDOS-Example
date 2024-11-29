#!/bin/bash

# Exit on error
#set -e

# This script deploys the chart using the zenoh-bridge-dds
# Usage:
# ./offload-switch-deploy.sh [switch|delete|apply]
# switch: switches the deployment between local and remote mode
# delete: deletes the deployment
# apply: installs the deployment

PATH_TO_FOLDER="./k8s_manifests"
NAME_DEPLOYMENT_TO_ROLLOUT="image-recognition"

status="LOCAL"

# Function to wait for a deployment to complete its rollout
wait_for_rollout() {
  local deployment_name=$1
  local namespace=$2

  echo "Waiting for deployment $deployment_name to complete its rollout..."
  kubectl rollout status deployment "$deployment_name" -n "$namespace"
}

# Function to handle the switch command
handle_switch() {
  if [ "$status" == "LOCAL" ]; then
      kubectl patch deployment $NAME_DEPLOYMENT_TO_ROLLOUT -n default --type='json' -p='[{
        "op": "replace",
        "path": "/spec/template/spec/affinity",
        "value": {
          "nodeAffinity": {
            "requiredDuringSchedulingIgnoredDuringExecution": {
              "nodeSelectorTerms": [
                {
                  "matchExpressions": [
                    {
                      "key": "liqo.io/type",
                      "operator": "In",
                      "values": ["virtual-node"]
                    }
                  ]
                }
              ]
            }
          }
        }
      }]'
      wait_for_rollout $NAME_DEPLOYMENT_TO_ROLLOUT default
      status="REMOTE"
  elif [ "$status" == "REMOTE" ]; then
      kubectl patch deployment "$NAME_DEPLOYMENT_TO_ROLLOUT" -n default --type='json' -p='[{
        "op": "replace",
        "path": "/spec/template/spec/affinity",
        "value": {
          "nodeAffinity": {
            "requiredDuringSchedulingIgnoredDuringExecution": {
              "nodeSelectorTerms": [
                {
                  "matchExpressions": [
                    {
                      "key": "liqo.io/type",
                      "operator": "NotIn",
                      "values": ["virtual-node"]
                    }
                  ]
                }
              ]
            }
          }
        }
      }]'
      wait_for_rollout "$NAME_DEPLOYMENT_TO_ROLLOUT" default
      status="LOCAL"    
  else
      echo "Invalid status: $status"
  fi
}



# Function to handle termination
terminate_deployment() {
  echo "Terminating deployment..."
  kubectl delete -f k8s_manifests
  liqoctl unoffload namespace default
  exit 0
}

# Trap SIGINT and SIGTERM to terminate the deployment
trap terminate_deployment SIGINT SIGTERM


liqoctl offload namespace default
kubectl apply -f k8s_manifests
# Monitor for the switch and monitor commands
while true; do
  read -r -p "Enter command (switch to switch mode, monitor to monitor pods, exit to exit): " cmd
  if [ "$cmd" == "switch" ] || [ "$cmd" == "s" ] || [ "$cmd" == "sw" ]; then
    handle_switch
  elif [ "$cmd" == "monitor" ] || [ "$cmd" == "m" ] || [ "$cmd" == "mon" ]; then
    kubectl get pods -o=wide
  elif [ "$cmd" == "exit" ] || [ "$cmd" == "quit" ] || [ "$cmd" == "q" ]; then
    terminate_deployment
  fi
done