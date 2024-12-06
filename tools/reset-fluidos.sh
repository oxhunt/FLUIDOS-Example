#!/bin/bash

# this script is used to reset the fluidos namespace to its initial state by deleting all the resources that have been created

liqoctl unoffload namespace default --skip-confirm


liqoctl unpeer --skip-confirm

# this command gets the list of resource types that are present in the fluidos namespace: 
# `kubectl api-resources --verbs=list --namespaced -o name -n fluidos | grep fluidos`

# Results in client
# flavors.nodecore.fluidos.eu
#
# discoveries.advertisement.fluidos.eu
# peeringcandidates.advertisement.fluidos.eu
# knownclusters.network.fluidos.eu
# allocations.nodecore.fluidos.eu
# serviceblueprints.nodecore.fluidos.eu
# solvers.nodecore.fluidos.eu
# contracts.reservation.fluidos.eu
# reservations.reservation.fluidos.eu
# transactions.reservation.fluidos.eu


# Results in Provider
# flavors.nodecore.fluidos.eu
#
# discoveries.advertisement.fluidos.eu
# peeringcandidates.advertisement.fluidos.eu
# knownclusters.network.fluidos.eu
# allocations.nodecore.fluidos.eu
# serviceblueprints.nodecore.fluidos.eu
# solvers.nodecore.fluidos.eu
# contracts.reservation.fluidos.eu
# reservations.reservation.fluidos.eu
# transactions.reservation.fluidos.eu

# delete all the resources in the fluidos namespace except the flavors
resources_to_delete="discoveries.advertisement.fluidos.eu\
    peeringcandidates.advertisement.fluidos.eu\
    knownclusters.network.fluidos.eu\
    allocations.nodecore.fluidos.eu\
    serviceblueprints.nodecore.fluidos.eu\
    solvers.nodecore.fluidos.eu\
    contracts.reservation.fluidos.eu\
    reservations.reservation.fluidos.eu\
    transactions.reservation.fluidos.eu"

for resource in $resources_to_delete; do
    kubectl delete $resource --all -n fluidos
done