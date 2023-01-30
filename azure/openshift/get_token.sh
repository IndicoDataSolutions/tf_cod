#!/bin/bash

name=$1
resource_group=$2
kube_config=$3

set -e

creds_file="/tmp/${name}-${resource_group}_creds.json"
info_file="/tmp/${name}-${resource_group}_info.json"
kubeconfig_file="/tmp/${name}-${resource_group}.openshift_kubeconfig"

if [ -f $creds_file ]; then
  rm $creds_file
fi

if [ -f $info_file ]; then
  rm $info_file
fi

az login --service-principal -u "$ARM_CLIENT_ID" -p "$ARM_CLIENT_SECRET" --tenant "$ARM_TENANT_ID" > /dev/null
az aro list-credentials --name "$1" --resource-group "$2" --output json > $creds_file
az aro show --name "$1" --resource-group "$2" --query '{api:apiserverProfile.ip, ingress:ingressProfiles[0].ip, consoleUrl:consoleProfile.url, apiUrl:apiserverProfile.url}' --output json > $info_file

username=$(cat $creds_file | jq -r '.kubeadminUsername')
password=$(cat $creds_file | jq -r '.kubeadminPassword')
api_ip=$(cat $info_file | jq -r '.api')
api_url=$(cat $info_file | jq -r '.apiUrl')

if [ "$kube_config" != "" ]; then
  kubeconfig_file=$kube_config
  echo "Using $kubeconfig_file"
fi

oc login --kubeconfig=$kubeconfig_file $api_url --username "${username}" --password "${password}" --insecure-skip-tls-verify=true &> /dev/null

os=$(uname -s)
if [ "$os" == 'Darwin' ]; then
an_hour_from_now=$(date -v+1H -u '+%Y-%m-%dT%H:%M:%SZ')
else
an_hour_from_now=$(date -u -d '+1 hour' '+%Y-%m-%dT%H:%M:%SZ')
fi

echo date > lastrun.txt
token=$(cat /tmp/.openshift_kubeconfig | yq '.users[0].user.token')
version='client.authentication.k8s.io/v1beta1'
json=$( jq -n -c \
  --arg version "$version" \
  --arg api_ip "$api_url" \
  --arg token "$token" \
  --arg an_hour_from_now "$an_hour_from_now" \
  '{kind: "ExecCredential", apiVersion: $version, spec: {cluster: {server: $api_ip, "insecure-skip-tls-verify": true}}, status: {expirationTimeStamp: $an_hour_from_now, token: $token}}' )
echo $json             