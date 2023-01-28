#!/bin/bash

az login --service-principal -u "$ARM_CLIENT_ID" -p "$ARM_CLIENT_SECRET" --tenant "$ARM_TENANT_ID"
az aro list-credentials --name "$1" --resource-group "$2" --output json > creds.json
az aro show --name "$1" --resource-group "$2" --query '{api:apiserverProfile.ip, consoleIp:ingressProfiles[0].ip, consoleUrl:consoleProfile.url, apiUrl:apiserverProfile.url}' --output json > info.json

oc version

username=$(cat creds.json | jq -r '.kubeadminUsername')
password=$(cat creds.json | jq -r '.kubeadminPassword')
api_ip=$(cat info.json | jq -r '.api')
api_url=$(cat info.json | jq -r '.apiUrl')
console_ip=$(cat info.json | jq -r '.consoleIp')
console_url=$(cat info.json | jq -r '.consoleUrl')

export KUBECONFIG="/tmp/.openshift_kubeconfig"
touch "/tmp/.openshift_kubeconfig"
oc login $api_url --username ${username} --password ${password} > /dev/null
user_token=$(cat /tmp/.openshift_kubeconfig | yq '.users[0].user.token')

oc get sa --namespace terraform-sa &> /dev/null
if [ $? -ne 0 ]; then 
  echo "Creating terraform-sa"
  oc create sa --namespace default erraform-sa
fi

oc get clusterrolebinding terraform-sa &> /dev/null
if [ $? -ne 0 ]; then 
  echo "Creating terraform-sa cluster-admin rolebinding"
  oc create clusterrolebinding terraform-sa --clusterrole=cluster-admin --serviceaccount=default:terraform-sa
fi
secret0_name=$(oc get sa -n default terraform-sa -o json | jq -r '.secrets[0].name')
secret1_name=$(oc get sa -n default terraform-sa -o json | jq -r '.secrets[1].name')
oc get clusterrolebinding terraform-sa -o yaml

if [[ "$secret0_name" == *"dockercfg"* ]]; then
  secret_name=$secret1_name
fi

if [[ "$secret1_name" == *"dockercfg"* ]]; then
  secret_name=$secret0_name
fi
sa_token=$(oc get secret $secret_name -o json | jq -r '.data.token')
sa_cert=$(oc get secret $secret_name -o json | jq -r '.data."ca.crt"')

echo "${username}" > /tmp/username
echo "${password}" > /tmp/password
echo "${api_ip}" > /tmp/api_ip
echo "${api_url}" > /tmp/api_url
echo "${console_ip}" > /tmp/console_ip
echo "${console_url}" > /tmp/console_url
echo "terraform-sa" > /tmp/sa_username
echo "${sa_token}" > /tmp/sa_token
echo "${user_token}" > /tmp/user_token
echo "${sa_cert}" > /tmp/sa_cert

