#!/bin/bash

set -x

KUBE_CA_CERT=$(kubectl config view --raw --minify --flatten -o jsonpath='{.clusters[].cluster.certificate-authority-data}' | base64 --decode)
TOKEN_REVIEW_JWT=$(kubectl get secret vault-auth -o go-template='{{ .data.token }}' | base64 --decode) 
KUBE_HOST=$(kubectl config view --raw --minify --flatten --output='jsonpath={.clusters[].cluster.server}')


auth_name="kubernetes_test"
policy_name="${auth_name}_policy"

vault auth enable -path=${auth_name} kubernetes

vault write auth/${auth_name}/config   token_reviewer_jwt="$TOKEN_REVIEW_JWT"   kubernetes_host="$KUBE_HOST"   kubernetes_ca_cert="$KUBE_CA_CERT" disable_local_ca_jwt="true"

vault read auth/${auth_name}/config

vault policy write $policy_name - <<EOF
path "secret/data/$olicy_name/config" {
  capabilities = ["read"]
}
EOF

vault write auth/${auth_name}/role/devweb-app \
  bound_service_account_names=vault-auth \
  bound_service_account_namespaces=default \
  policies=$policy_name \
  ttl=24h

curl \
     --request POST \
     --data '{"jwt": "'$TOKEN_REVIEW_JWT'", "role": "devweb-app"}' \
     https://vault.devops.indico.io/v1/auth/${auth_name}/login
