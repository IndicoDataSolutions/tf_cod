data "vault_kv_secret_v2" "account-robot-credentials" {
  mount = "customer-${var.aws_account}"
  name  = "harbor-registry"
}

resource "aws_efs_access_point" "local-registry" {
  root_directory {
    path = "/registry"
    creation_info {
      owner_gid   = 1000
      owner_uid   = 1000
      permissions = "0777"
    }
  }

  posix_user {
    gid = 1000
    uid = 1000
  }
  file_system_id = var.efs_filesystem_id
}


# TODO: move all kubernetes resources here to the helm chart
resource "kubernetes_persistent_volume_claim" "local-registry" {
  depends_on = [
    kubernetes_namespace.local-registry,
    kubernetes_persistent_volume.local-registry
  ]

  metadata {
    name      = "local-registry"
    namespace = "local-registry"
  }
  spec {
    access_modes       = ["ReadWriteMany"]
    storage_class_name = "local-registry"
    resources {
      requests = {
        storage = "100Gi"
      }
    }
    volume_name = "local-registry"
  }
}

resource "kubernetes_persistent_volume" "local-registry" {
  metadata {
    name = "local-registry"
  }

  spec {
    capacity = {
      storage = "100Gi"
    }

    access_modes       = ["ReadWriteMany"]
    storage_class_name = "local-registry"

    persistent_volume_source {
      csi {
        driver        = "efs.csi.aws.com"
        volume_handle = "${var.efs_filesystem_id}::${aws_efs_access_point.local-registry.id}"
      }
    }
  }
}

resource "kubernetes_namespace" "local-registry" { #TODO: set create_namespace = true for local-registry
  metadata {
    name = "local-registry"
  }
}

resource "kubernetes_storage_class_v1" "local-registry" { #TODO: add to local-registry helm chart
  metadata {
    name = "local-registry"
  }

  storage_provisioner = "efs.csi.aws.com"
  reclaim_policy      = "Retain"
}

resource "helm_release" "local-registry" {
  depends_on = [
    kubernetes_namespace.local-registry,
    kubernetes_persistent_volume_claim.local-registry
  ]

  verify           = false
  name             = "local-registry"
  create_namespace = true
  namespace        = "local-registry"
  repository       = var.ipa_repo
  chart            = "local-registry"
  version          = var.local_registry_version
  wait             = false
  timeout          = "1800" # 30 minutes
  disable_webhooks = false

  values = [<<EOF
cert-manager:
  enabled: false

ingress-nginx:
  enabled: true
  
  controller:
    ingressClass: nginx-internal
    ingressClassResource:
      controllerValue: "k8s.io/ingress-nginx-internal"
      name: nginx-internal
    admissionWebhooks:
      enabled: false
    autoscaling:
      enabled: true
      maxReplicas: 12
      minReplicas: 6
      targetCPUUtilizationPercentage: 50
      targetMemoryUtilizationPercentage: 50
    resources:
      requests:
        cpu: 1
        memory: 2Gi
    service:
      external:
        enabled: false
      internal:
        annotations:
          service.beta.kubernetes.io/aws-load-balancer-internal: "true"
        enabled: true

docker-registry:
  service:
    annotations: 
      external-dns.alpha.kubernetes.io/hostname: "local-registry.${var.dns_name}"
  extraEnvVars:
  - name: GOGC
    value: "50"
  ingress:
    className: nginx-internal
    enabled: true
    annotations:
      cert-manager.io/cluster-issuer: zerossl
      kubernetes.io/ingress.class: nginx-internal
      service.beta.kubernetes.io/aws-load-balancer-internal: "true"

    labels: 
      acme.cert-manager.io/dns01-solver: "true"
    hosts:
    - local-registry.${var.dns_name}
    tls:
    - hosts:
      - local-registry.${var.dns_name}
      secretName: registry-tls
  
  persistence:
    deleteEnabled: true
    enabled: true
    size: 100Gi
    existingClaim: local-registry
    storageClass: local-registry

  proxy:
    enabled: true
    remoteurl: https://harbor.devops.indico.io
    secretRef: remote-access
  replicaCount: 3
  
  secrets:
    htpasswd: local-user:${var.htpasswd.bcrypt}

localPullSecret:
  password: ${var.general_password.result}
  secretName: local-pull-secret
  username: local-user

metrics-server:
  apiService:
    create: true
  enabled: false

proxyRegistryAccess:
  proxyPassword: ${jsondecode(data.vault_kv_secret_v2.account-robot-credentials.data_json)["harbor_password"]}
  proxyPullSecretName: remote-access
  proxyUrl: https://harbor.devops.indico.io
  proxyUsername: ${jsondecode(data.vault_kv_secret_v2.account-robot-credentials.data_json)["harbor_username"]}
  
registryUrl: local-registry.${var.dns_name}
restartCronjob:
  cronSchedule: 0 0 */3 * *
  disabled: false
  image: bitnami/kubectl:1.20.13
  EOF
  ]
}
