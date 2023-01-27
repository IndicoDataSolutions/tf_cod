#!/bin/bash
az login --service-principal -u "$ARM_CLIENT_ID" -p "$ARM_CLIENT_SECRET" --tenant "$ARM_TENANT_ID"
az aro list-credentials --name "$1" --resource-group "$2" --output json > creds.json
az aro show --name "$1" --resource-group "$2" --query '{api:apiserverProfile.ip, consoleIp:ingressProfiles[0].ip, consoleUrl:consoleProfile.url, apiUrl:apiserverProfile.url}' --output json > info.json

username=$(cat creds.json | jq -r '.kubeadminUsername')
password=$(cat creds.json | jq -r '.kubeadminPassword')
api_ip=$(cat info.json | jq -r '.api')
api_url=$(cat info.json | jq -r '.apiUrl')
console_ip=$(cat info.json | jq -r '.consoleIp')
console_url=$(cat info.json | jq -r '.consoleUrl')

echo "${username}" > /tmp/username
echo "${password}" > /tmp/password
echo "${api_ip}" > /tmp/api_ip
echo "${api_url}" > /tmp/api_url
echo "${console_ip}" > /tmp/console_ip
echo "${console_url}" > /tmp/console_url


