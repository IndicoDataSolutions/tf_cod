#!/bin/bash

set -x

name=$1
resource_group=$2

creds_file='/tmp/creds.json'
info_file='/tmp/info.json'

if [ -f $creds_file ]; then
  rm $creds_file
fi

if [ -f $info_file ]; then
  rm $info_file
fi

az login --service-principal -u "$ARM_CLIENT_ID" -p "$ARM_CLIENT_SECRET" --tenant "$ARM_TENANT_ID" > /dev/null
az aro list-credentials --name "$1" --resource-group "$2" --output json > $creds_file
az aro show --name "$1" --resource-group "$2" --query '{api:apiserverProfile.ip, ingress:ingressProfiles[0].ip, consoleUrl:consoleProfile.url, apiUrl:apiserverProfile.url}' --output json > $info_file

api_ip=$(cat $info_file | jq -r '.api')
api_url=$(cat $info_file | jq -r '.apiUrl')

suffix="/"
prefix="https://"
host=${api_url#"$prefix"}
host=${host%"$suffix"}
echo $host

if true | openssl s_client -connect $host 2>/dev/null |  openssl x509 -text -noout; then
  echo "Certificate is not expired"
  exit 0
else
  echo "Certificate is expired"
  exit 1
fi