#!/bin/bash
set -e 

repo=$1
version=$2

retry_attempts=10 # minutes max
until [ $retry_attempts -le 0 ]
do
  if curl -f -s -X 'GET' \
    "https://harbor.devops.indico.io/api/v2.0/chartrepo/indico-charts/charts/${repo}/${version}/labels" \
    -H "accept: application/json" \
    -H "authorization: Basic ${HARBOR_API_TOKEN}" \
    > /dev/null; then
    echo "Found the Chart ${repo}/${version}"
    exit 0
  else
    echo "${retry_attempts}: Chart ${repo}/${version} not found, waiting 1 minute"
    sleep 60
  fi
done
exit 1



