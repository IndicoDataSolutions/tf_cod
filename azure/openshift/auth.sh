#!/bin/bash
name=$1
resource_group=$2

#set -x
prefix=$(prefix=$(openssl rand -hex 20)
creds_file="/tmp/$prefix-${name}-${resource_group}_creds.json"
info_file="/tmp/$prefix-${name}-${resource_group}_info.json"

if [ -f $creds_file ]; then
  rm $creds_file
fi

if [ -f $info_file ]; then
  rm $info_file
fi

az login --service-principal -u "$ARM_CLIENT_ID" -p "$ARM_CLIENT_SECRET" --tenant "$ARM_TENANT_ID" &> /dev/null
if [ $? -ne 0 ]; then
  echo "Failed to login"
 exit 1
fi
az aro list-credentials --name "$1" --resource-group "$2" --output json > $creds_file
if [ $? -ne 0 ]; then
  echo "Failed to list-credentials"
 exit 1
fi
az aro show --name "$1" --resource-group "$2" --query '{api:apiserverProfile.ip, consoleIp:ingressProfiles[0].ip, consoleUrl:consoleProfile.url, apiUrl:apiserverProfile.url}' --output json > $info_file
if [ $? -ne 0 ]; then
  echo "Failed to show cluster information"
 exit 1
fi

username=$(cat $creds_file | jq -r '.kubeadminUsername')
password=$(cat $creds_file | jq -r '.kubeadminPassword')
api_ip=$(cat $info_file | jq -r '.api')
api_url=$(cat $info_file | jq -r '.apiUrl')

oc login $api_url --username "${username}" --password "${password}"

set +e
if [ -f $creds_file ]; then
  rm $creds_file
fi

if [ -f $info_file ]; then
  rm $info_file
fi

