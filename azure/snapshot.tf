# Create a secret with the workload identity so azcopy can execute
resource "kubernetes_secret" "cod-snapshot-client-id" {
  count = var.restore_snapshot_enabled == true ? 1 : 0

  metadata {
    name      = "cod-snapshot-client-id"
    namespace = "default"
  }

  data = {
    id = "${azuread_application.workload_identity.application_id}"
  }
}

resource "helm_release" "cod-snapshot-restore" {
  depends_on = [
    helm_release.ipa-pre-requisites,
    kubernetes_secret.cod-snapshot-client-id,
    azuread_application_federated_identity_credential.workload_snapshot_identity,
    kubernetes_service_account.workload_identity
  ]

  count            = var.restore_snapshot_enabled == true ? 1 : 0
  name             = "cod-snapshot-restore"
  create_namespace = true
  namespace        = "default"
  repository       = var.ipa_repo
  chart            = "cod-snapshot-restore"
  version          = var.cod_snapshot_restore_version
  wait             = true
  timeout          = "3600" # 120 minutes
  disable_webhooks = false

  values = [<<EOF
image:
  repository: harbor.devops.indico.io/indico/cod-snapshot-azure

snapshot:
  labels:
    "azure.workload.identity/use": "true"
  command: /app/restore-azure.sh
  aws_account_name: unused
  name: "${var.restore_snapshot_name}"
  env:
    - name: STORAGE_ACCOUNT_NAME
      value: ${local.storage_account_name}
    - name: IDENTITY_CLIENT_ID
      valueFrom:
        secretKeyRef:
          name: cod-snapshot-client-id
          key: id

podAnnotations:
  "azure.workload.identity/inject-proxy-sidecar": "true"

serviceAccount:
  labels:
    "azure.workload.identity/use": "true"

  # https://learn.microsoft.com/en-us/azure/aks/workload-identity-overview
  annotations:
    "azure.workload.identity/client-id": "${azuread_application.workload_identity.application_id}"
    "azure.workload.identity/tenant-id": "${data.azurerm_client_config.current.tenant_id}"
  EOF
  ]
}

# add label "azure.workload.identity/use" = "true" to cod-snapshot service account
# add annotation  "azure.workload.identity/client-id" = azuread_application.workload_identity.application_id to the cod-snapshot service account
# associate the sa with the deployment job workload-identity-storage-account
# need the client id of azuread_application.workload_identity.application_id
# azcopy login --identity --identity-client-id azuread_application.workload_identity.application_id
# add annotation azure.workload.identity/inject-proxy-sidecar: true to the cod-snapshot deployment job
# ./azcopy cp /etc  https://indicodevazuresnapshots.blob.core.windows.net/blob/azure546  --from-to LocalBlob --recursive
