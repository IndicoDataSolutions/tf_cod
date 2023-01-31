#!/bin/bash

name=$1
resource_group=$2
kube_config=$3

access_crt=/tmp/${name}-${resource_group}-access.crt
ca_crt=/tmp/${name}-${resource_group}-ca.crt
crb_yaml=/tmp/${name}-${resource_group}-crb.yaml
csr_yaml=/tmp/${name}-${resource_group}-csr.yaml
csr_file=/tmp/${name}-${resource_group}.csr
key_file=/tmp/${name}-${resource_group}.key

NEW_KUBECONFIG="/tmp/.${name}-${resource_group}_kubeconfig"

set -x

creds_file="/tmp/${name}-${resource_group}_creds.json"
info_file="/tmp/${name}-${resource_group}_info.json"

if [ -f $NEW_KUBECONFIG ]; then
  rm $NEW_KUBECONFIG
fi

if [ -f $creds_file ]; then
  rm $creds_file
fi

if [ -f $info_file ]; then
  rm $info_file
fi

az login --service-principal -u "$ARM_CLIENT_ID" -p "$ARM_CLIENT_SECRET" --tenant "$ARM_TENANT_ID"
az aro list-credentials --name "$1" --resource-group "$2" --output json > $creds_file
az aro show --name "$1" --resource-group "$2" --query '{api:apiserverProfile.ip, consoleIp:ingressProfiles[0].ip, consoleUrl:consoleProfile.url, apiUrl:apiserverProfile.url}' --output json > $info_file

cat $creds_file
cat $info_file

username=$(cat $creds_file | jq -r '.kubeadminUsername')
password=$(cat $creds_file | jq -r '.kubeadminPassword')
api_ip=$(cat $info_file | jq -r '.api')
api_url=$(cat $info_file | jq -r '.apiUrl')
console_ip=$(cat $info_file | jq -r '.consoleIp')
console_url=$(cat $info_file | jq -r '.consoleUrl')

logged_in="false"
retry_attempts=10
until [ $logged_in == "true" ] || [ $retry_attempts -le 0 ]
do
  # if you use --insecure-skip-tls-verify=true then the sa account will prompt for a password on the oc login below
  oc login $api_url --username "${username}" --password "${password}" --kubeconfig $NEW_KUBECONFIG --insecure-skip-tls-verify=false
  if [ $? -eq 0 ]; then
    echo "Successfully Logged in to new cluster $api_url"
    logged_in="true"
  else
    echo "Error: Unable to login, waiting for certificate to become valid, trying again in 30 seconds... ${retry_attempts}"
    sleep 30
    ((retry_attempts--))
  fi
done

cat $NEW_KUBECONFIG
export KUBECONFIG=$NEW_KUBECONFIG

oc whoami
oc get csr ${name}-${resource_group}-access
if [ $? -eq 0 ]; then
  echo "CSR ${name}-${resource_group}-access already exists, finished."
  oc get user
fi

oc get user terraform-sa
[ $? -eq 0 ] && oc delete user terraform-sa
oc create user terraform-sa

cat << EOF >> $crb_yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: terraform-sa-admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: User
  name: terraform-sa
EOF

oc get clusterrolebinding terraform-sa-admin
[ $? -eq 0 ] && oc delete clusterrolebinding terraform-sa-admin

oc create -f $crb_yaml

openssl req -new -newkey rsa:4096 -nodes -keyout $key_file -out $csr_file -subj "/CN=terraform-sa"

cat << EOF >> $csr_yaml
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: ${name}-${resource_group}-access
spec:
  signerName: kubernetes.io/kube-apiserver-client
  groups:
  - system:authenticated
  request: $(cat $csr_file | base64 | tr -d '\n')
  usages:
  - client auth
EOF

oc get csr
oc get csr ${name}-${resource_group}-access
[ $? -eq 0 ] && oc delete csr ${name}-${resource_group}-access 

oc create -f $csr_yaml

oc adm certificate approve ${name}-${resource_group}-access
oc get csr ${name}-${resource_group}-access -o jsonpath='{.status.certificate}' | base64 -d > $access_crt

oc -n openshift-authentication rsh `oc --kubeconfig $NEW_KUBECONFIG get pods -n openshift-authentication -o name | head -1` cat /run/secrets/kubernetes.io/serviceaccount/ca.crt | base64  > $ca_crt
oc config set-credentials terraform-sa --client-certificate=$access_crt --client-key=$key_file --embed-certs --kubeconfig=$NEW_KUBECONFIG
oc config set-context terraform-sa --cluster=$(oc --kubeconfig $NEW_KUBECONFIG config view -o jsonpath='{.clusters[0].name}') --namespace=default --user=terraform-sa  --kubeconfig=$NEW_KUBECONFIG
oc config use-context terraform-sa --kubeconfig=$NEW_KUBECONFIG

oc whoami 
export KUBECONFIG=$NEW_KUBECONFIG
oc login -u terraform-sa
oc whoami
oc get ns | grep terraform-sa
[ $? -ne 0 ] && oc create ns terraform-sa

oc get ns terraform-sa
oc delete ns terraform-sa

#oc create sa -n default foobar
#oc get sa -n default

echo "cp $KUBECONFIG ./$name.kubeconfig"
cp $NEW_KUBECONFIG ./$name.kubeconfig

#  Now, we get back the output of the script
#output "kubernetes_host" 
kubernetes_host=/tmp/${name}-${resource_group}.kubernetes_host
oc --kubeconfig $NEW_KUBECONFIG config view -o jsonpath='{.clusters[0].cluster.server}' > $kubernetes_host
cat $kubernetes_host

#output "kubernetes_client_certificate" 
kubernetes_client_certificate=/tmp/${name}-${resource_group}.kubernetes_client_certificate
cat $access_crt > $kubernetes_client_certificate

#output "kubernetes_client_key" 
kubernetes_client_key=/tmp/${name}-${resource_group}.kubernetes_client_key
cat $key_file > $kubernetes_client_key

#output "kubernetes_cluster_ca_certificate" 
kubernetes_cluster_ca_certificate=/tmp/${name}-${resource_group}.kubernetes_cluster_ca_certificate
cat $ca_crt > $kubernetes_cluster_ca_certificate

kube_config_file=/tmp/${name}-${resource_group}.kube_config
cp $NEW_KUBECONFIG $kube_config_file

echo $api_ip > /tmp/${name}-${resource_group}.openshift_api_ip
echo $console_ip > /tmp/${name}-${resource_group}.openshift_console_ip

#echo "kubernetes_host"
#cat $kubernetes_host

#echo "kubernetes_client_certificate"
#cat $kubernetes_client_certificate

#echo "kubernetes_client_key"
#cat $kubernetes_client_key

#echo "kubernetes_cluster_ca_certificate"
#cat $kubernetes_cluster_ca_certificate
