#!/bin/bash

name=$1
resource_group=$2
kube_config=$3

set -e

echo "az login"
az login --service-principal -u "$ARM_CLIENT_ID" -p "$ARM_CLIENT_SECRET" --tenant "$ARM_TENANT_ID"
echo "az list creds"
az aro list-credentials --name "$1" --resource-group "$2" --output json
az aro list-credentials --name "$1" --resource-group "$2" --output json > creds.json
echo "az list show data"
az aro show --name "$1" --resource-group "$2" --query '{api:apiserverProfile.ip, ingress:ingressProfiles[0].ip, consoleUrl:consoleProfile.url, apiUrl:apiserverProfile.url}' --output json
az aro show --name "$1" --resource-group "$2" --query '{api:apiserverProfile.ip, ingress:ingressProfiles[0].ip, consoleUrl:consoleProfile.url, apiUrl:apiserverProfile.url}' --output json > info.json

username=$(cat creds.json | jq -r '.kubeadminUsername')
password=$(cat creds.json | jq -r '.kubeadminPassword')
api_ip=$(cat info.json | jq -r '.api')
api_url=$(cat info.json | jq -r '.apiUrl')

if [ "${kube_config}" == "" ]; then
  export KUBECONFIG="/tmp/.openshift_kubeconfig"
  if [ -f "$KUBECONFIG" ]; then
    rm $KUBECONFIG
  fi
  touch "/tmp/.openshift_kubeconfig"
else 
  echo "Updating $KUBECONFIG"
fi
echo "oc login"
oc login $api_url --username "${username}" --password "${password}" --insecure-skip-tls-verify=true
os=$(uname -s)
if [ "$os" == 'Darwin' ]; then
an_hour_from_now=$(date -v+1H -u '+%Y-%m-%dT%H:%M:%SZ')
else
an_hour_from_now=$(date -u -d '+1 hour' '+%Y-%m-%dT%H:%M:%SZ')
fi

token=$(cat /tmp/.openshift_kubeconfig | yq '.users[0].user.token')
version='client.authentication.k8s.io/v1beta1'
json=$( jq -n -c \
  --arg version "$version" \
  --arg api_ip "$api_url" \
  --arg token "$token" \
  --arg an_hour_from_now "$an_hour_from_now" \
  '{kind: "ExecCredential", apiVersion: $version, spec: {cluster: {server: $api_ip, "insecure-skip-tls-verify": true}}, status: {expirationTimeStamp: $an_hour_from_now, token: $token}}' )
echo $json             