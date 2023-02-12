#!/bin/bash
namespace=$1
subscription=$2

set -x
ready="false"
retry_attempts=60
healthy="Available"

until ([ "$ready" == "$healthy" ] && [ "$conflicts" == "NoConflicts" ]) || [ $retry_attempts -le 0 ]
do
  ready=$(kubectl get nodefeaturediscovery -n $1 $2 -o json | jq -r '.status.conditions[] | select((.status == "True") and (.type == "Available")) | .type')
  conflicts=$(kubectl get operator nfd.openshift-nfd -o json | jq -r '.status.components.refs[] | select((.kind == "CustomResourceDefinition") and (.name == "nodefeaturediscoveries.nfd.openshift.io")) | .conditions[] | select(.status == "True" and .type == "NamesAccepted") | .reason')

  if [ "$ready" == "$healthy" ] && [ "$conflicts" == "NoConflicts" ]; then
    echo "$1/$2 is $healthy and $conflicts"
  else
    echo "Not ready, waiting ${retry_attempts} ${ready}"
    kubectl get nodefeaturediscovery -n $1 $2 -o json | jq -r '.status.conditions[]'
    sleep 30
    ((retry_attempts--))
  fi
done

