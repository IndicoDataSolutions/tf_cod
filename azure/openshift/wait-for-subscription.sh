#!/bin/bash
namespace=$1
subscription=$2

#set -x
ready="false"
retry_attempts=60
healthy="AllCatalogSourcesHealthy"

until [ $ready == $healthy ] || [ $retry_attempts -le 0 ]
do
  ready=$(kubectl get subscription -n $1 $2 -o json | jq -r '.status.conditions[] | select((.status == "False") and (.type == "CatalogSourcesUnhealthy")) | .reason')
  if [ $ready != $healthy ]; then
    echo "Not ready, waiting ${retry_attempts} ${ready}"
    sleep 30
    ((retry_attempts--))
  else
    echo "$1/$2 is ready"
  fi
done

