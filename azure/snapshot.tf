#data "git" "snapshots" {
#  name                = replace(lower("${var.account}snapshots"), "-", "")
#  resource_group_name = var.snapshots_resource_group_name
#}


# associate the sa with the deployment job workload-identity-storage-account
# need the client id of azuread_application.workload_identity.application_id
# azcopy login --identity --identity-client-id azuread_application.workload_identity.application_id
# add annotation azure.workload.identity/inject-proxy-sidecar: true to the cod-snapshot deployment job
# ./azcopy cp /etc  https://indicodevazuresnapshots.blob.core.windows.net/blob/azure546  --from-to LocalBlob --recursive

resource "kubectl_manifest" "snapshot-service-account" {
  depends_on = [
    helm_release.ipa-pre-requisites
  ]
  count     = var.restore_snapshot_enabled == true ? 1 : 0
  yaml_body = <<YAML
apiVersion: v1
kind: ServiceAccount
metadata:
  name: snapshots
  namespace: default

YAML
}

resource "kubectl_manifest" "snapshot-cluster-role" {
  depends_on = [
    helm_release.ipa-pre-requisites
  ]
  count     = var.restore_snapshot_enabled == true ? 1 : 0
  yaml_body = <<YAML
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: snapshot-role
 
rules:
  - apiGroups: ["*"]
    resources: [
      "namespaces",
      "secrets"
    ]
    verbs:  ["get", "list", "watch", "create", "patch"]
YAML
}

resource "kubectl_manifest" "snapshot-cluster-role-binding" {
  depends_on = [
    helm_release.ipa-pre-requisites
  ]
  count     = var.restore_snapshot_enabled == true ? 1 : 0
  yaml_body = <<YAML
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: snapshots
 
subjects:
  - kind: ServiceAccount
    name: snapshots
    namespace: default
roleRef:
  kind: ClusterRole
  name: snapshot-role
  apiGroup: rbac.authorization.k8s.io
YAML
}


resource "kubernetes_job" "snapshot-restore-job" {
  depends_on = [
    helm_release.ipa-pre-requisites,
    kubectl_manifest.snapshot-cluster-role-binding,
    kubectl_manifest.snapshot-cluster-role,
    kubectl_manifest.snapshot-service-account
  ]

  count = var.restore_snapshot_enabled == true ? 1 : 0
  metadata {
    name      = "cod-restore-snapshot"
    namespace = "default"
  }
  spec {
    completions = 1
    template {
      metadata {}
      spec {
        service_account_name = "snapshots"
        image_pull_secrets {
          name = "harbor-pull-secret"
        }
        container {
          name              = "restore"
          image             = "harbor.devops.indico.io/indico/cod-snapshot:latest"
          image_pull_policy = "Always"
          command           = ["bash", "/app/restore.sh", "${var.restore_snapshot_name}", "azure"]
          env {
            name = "DB_NAME"
            value_from {
              secret_key_ref {
                name = "postgres-data-pguser-indico"
                key  = "dbname"
              }
            }
          }
          env {
            name = "DB_HOST"
            value_from {
              secret_key_ref {
                name = "postgres-data-pguser-indico"
                key  = "host"
              }
            }
          }
          env {
            name = "DB_PORT"
            value_from {
              secret_key_ref {
                name = "postgres-data-pguser-indico"
                key  = "port"
              }
            }
          }
          env {
            name = "DB_USER"
            value_from {
              secret_key_ref {
                name = "postgres-data-pguser-indico"
                key  = "user"
              }
            }
          }
          env {
            name = "DB_PASSWORD"
            value_from {
              secret_key_ref {
                name = "postgres-data-pguser-indico"
                key  = "password"
              }
            }
          }

          volume_mount {
            name       = "root-nfs"
            mount_path = "/indicoapidata"
          }
        }
        restart_policy = "Never"
        volume {
          name = "root-nfs"
          persistent_volume_claim {
            claim_name = "read-write"
          }
        }
      }
    }
  }
  wait_for_completion = true

  # up to 30 minutes to
  timeouts {
    create = "30m"
    update = "30m"
  }

}
