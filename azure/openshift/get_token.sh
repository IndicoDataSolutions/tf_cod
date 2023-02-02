#!/bin/bash

api_url=$1
username=$2
password=$3

name=$(basename $1)
kube_config=/tmp/$name.kubeconfig

set -e

touch $kube_config
oc login --kubeconfig=$kube_config $api_url --username "${username}" --password "${password}" &> /dev/null

os=$(uname -s)
if [ "$os" == 'Darwin' ]; then
an_hour_from_now=$(date -v+1H -u '+%Y-%m-%dT%H:%M:%SZ')
else
an_hour_from_now=$(date -u -d '+1 hour' '+%Y-%m-%dT%H:%M:%SZ')
fi

echo date > lastrun.txt
token=$(cat $kube_config | yq '.users[0].user.token')
version='client.authentication.k8s.io/v1beta1'
json=$( jq -n -c \
  --arg version "$version" \
  --arg api_ip "$api_url" \
  --arg token "$token" \
  --arg an_hour_from_now "$an_hour_from_now" \
  '{kind: "ExecCredential", apiVersion: $version, spec: {}, status: {expirationTimestamp: $an_hour_from_now, token: $token}}' )
echo $json             