#!/bin/bash
namespace=$1
subscription=$2

set -x
ready="false"
retry_attempts=60
healthy="AllCatalogSourcesHealthy"

until [ $ready == $healthy ] || [ $retry_attempts -le 0 ]
do
  ready=$(kubectl get subscription -n $1 $2 -o json | jq -r '.items[0].status.conditions[] | select((.status == "False") and (.type == "CatalogSourcesUnhealthy")) | .reason')
  if [ $ready != $healthy ]; then
    echo "Not ready, sleeping 3"
    sleep 3
  else
    echo "$1/$2 is ready"
  fi
done

