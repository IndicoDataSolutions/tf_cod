#!/bin/bash

name=$1
resource_group=$2

set -e

#az aro show --name "$1" --resource-group "$2" --query '{api:apiserverProfile.ip, ingress:ingressProfiles[0].ip, url:consoleProfile.url}' 
az login --service-principal -u "$ARM_CLIENT_ID" -p "$ARM_CLIENT_SECRET" --tenant "$ARM_TENANT_ID" > /dev/null
az aro list-credentials --name "$1" --resource-group "$2" --output json > creds.json
az aro show --name "$1" --resource-group "$2" --query '{api:apiserverProfile.ip, ingress:ingressProfiles[0].ip, consoleUrl:consoleProfile.url, apiUrl:apiserverProfile.url}' --output json > info.json

username=$(cat creds.json | jq -r '.kubeadminUsername')
password=$(cat creds.json | jq -r '.kubeadminPassword')
api_ip=$(cat info.json | jq -r '.api')
export KUBECONFIG="/tmp/.openshift_kubeconfig"
touch "/tmp/.openshift_kubeconfig"
oc login https://${api_ip}:6443/ --insecure-skip-tls-verify=true --username "${username}" --password "${password}" > /dev/null
token=$(cat /tmp/.openshift_kubeconfig | yq '.users[0].user.token')
#echo \{\"kind\": \"ExecCredential\", \"apiVersion\": \"client.authentication.k8s.io/v1beta1\", \"spec\": {}, \"status\": {\"expirationTimestamp\": \"2030-01-27T20:04:59Z\",\"token\": \"${token}\"}\}
version='client.authentication.k8s.io/v1beta1'
json=$( jq -n -c \
  --arg version "$version" \
  --arg api_ip "https://:$api_ip:6443" \
  --arg token "$token" \
  '{kind: "ExecCredential", apiVersion: $version, spec: {cluster: {server: $api_ip, "insecure-skip-tls-verify": true}}, status: {expirationTimeStamp: "2030-01-27T20:00:00Z", token: $token}}' )
echo $json             