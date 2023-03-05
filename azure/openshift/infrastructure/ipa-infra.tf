locals {
  openshift_dns_credentials = <<EOF
  {
  "tenantId" : "${data.azurerm_client_config.current.tenant_id}",
  "subscriptionId" : "${split("/", data.azurerm_subscription.primary.id)[2]}",
  "resourceGroup" : "${var.common_resource_group}",
  "aadClientId": "${azuread_application.workload_identity.application_id}",
  "aadClientSecret": "${azuread_application_password.workload_identity.value}"
  }
  EOF

  azure_dns_credentials = <<EOF
  {
    "tenantId" : "${data.azurerm_client_config.current.tenant_id}",
    "subscriptionId" : "${split("/", data.azurerm_subscription.primary.id)[2]}",
    "resourceGroup" : "${var.common_resource_group}",
    "useManagedIdentityExtension" : true,
    "userAssignedIdentityID" : "${var.kubelet_identity_client_id}"
  }
  EOF

  external_dns_credentials = var.include_external_dns == true ? local.azure_dns_credentials : local.openshift_dns_credentials
  # https://docs.openshift.com/container-platform/4.10/nodes/pods/nodes-pods-autoscaling-custom.html
  prometheus_address = "http://monitoring-kube-prometheus-prometheus.${var.monitoring_namespace}.svc.cluster.local:9090/prometheus"

}

resource "kubernetes_namespace" "indico" {
  count = var.ipa_namespace != "default" ? 1 : 0

  metadata {
    name = var.ipa_namespace
  }

}
#TODO: move to prereqs
resource "kubernetes_secret" "harbor-pull-secret" {
  depends_on = [
    kubernetes_namespace.indico
  ]

  metadata {
    name      = "harbor-pull-secret"
    namespace = var.ipa_namespace
    annotations = {
      "reflector.v1.k8s.emberstack.com/reflection-allowed"      = true
      "reflector.v1.k8s.emberstack.com/reflection-auto-enabled" = true
    }
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = "${base64decode(var.harbor_pull_secret_b64)}"
  }
}

# this is needed in "default" for crds
resource "kubernetes_secret" "harbor-pull-secret-crds" {
  count = var.do_install_ipa_crds == true ? 1 : 0
  metadata {
    name      = "harbor-pull-secret"
    namespace = var.ipa_crds_namespace
    annotations = {
      "reflector.v1.k8s.emberstack.com/reflection-allowed"      = true
      "reflector.v1.k8s.emberstack.com/reflection-auto-enabled" = true
    }
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = "${base64decode(var.harbor_pull_secret_b64)}"
  }
}


resource "helm_release" "ipa-crds" {
  count = var.do_install_ipa_crds == true ? 1 : 0
  depends_on = [
    kubernetes_secret.harbor-pull-secret-crds,
    kubernetes_namespace.indico
  ]

  verify           = false
  name             = "ipa-crds"
  create_namespace = true
  namespace        = var.ipa_crds_namespace
  repository       = var.ipa_repo
  chart            = "ipa-crds"
  version          = var.ipa_crds_version
  timeout          = "600" # 10 minutes
  wait             = true

  values = [<<EOF
  crunchy-pgo:
    enabled: true
  
  aws-ebs-csi-driver:
    enabled: false

  cert-manager:
    nodeSelector:
      kubernetes.io/os: linux
    webhook:
      nodeSelector:
        kubernetes.io/os: linux
    cainjector:
      nodeSelector:
        kubernetes.io/os: linux
    enabled: true
    installCRDs: true
 EOF
  ]
}

resource "time_sleep" "wait_1_minutes_after_crds" {
  depends_on = [
    helm_release.ipa-crds,
    kubernetes_namespace.indico
  ]

  create_duration = "1m"
}

resource "azurerm_role_assignment" "external_dns" {
  count = var.include_external_dns == true ? 1 : 0

  scope                = data.azurerm_dns_zone.domain.0.id
  role_definition_name = "DNS Zone Contributor"
  principal_id         = var.kubelet_identity_object_id
}

resource "kubernetes_secret" "azure_storage_key" {
  metadata {
    name      = "azure-storage-key"
    namespace = var.ipa_namespace
  }

  data = {
    azurestorageaccountname = var.storage_account_name
    azurestorageaccountkey  = var.storage_account_primary_access_key
    AZURE_ACCOUNT_NAME      = var.storage_account_name
    AZURE_ACCOUNT_KEY       = var.storage_account_primary_access_key
    AZURE_CONTAINER         = var.blob_store_name
  }
}

resource "kubernetes_config_map" "azure_dns_credentials" {
  metadata {
    name      = "dns-credentials-config"
    namespace = var.ipa_namespace
  }

  data = {
    "azure.json" = local.external_dns_credentials
  }
}

data "vault_kv_secret_v2" "zerossl_data" {
  mount = var.vault_mount_path
  name  = "zerossl"
}

resource "helm_release" "crunchy-postgres" {
  depends_on = [
    helm_release.ipa-crds,
    time_sleep.wait_1_minutes_after_crds
  ]

  name             = "crunchy"
  create_namespace = true
  namespace        = var.ipa_namespace
  repository       = var.ipa_repo
  chart            = "crunchy-postgres"
  version          = "0.3.0"
  timeout          = "600" # 10 minutes
  wait             = true

  values = [<<EOF
  enabled: true
  postgres-data:
    openshift: true
    metadata:
      annotations:
        reflector.v1.k8s.emberstack.com/reflection-allowed: "true"
        reflector.v1.k8s.emberstack.com/reflection-auto-enabled: "true"
    instances:
    - affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: node_group
                operator: In
                values:
                - pgo-workers
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: postgres-operator.crunchydata.com/cluster
                operator: In
                values:
                - postgres-data
              - key: postgres-operator.crunchydata.com/instance-set
                operator: In
                values:
                - pgha1
            topologyKey: kubernetes.io/hostname
      metadata:
        annotations:
          reflector.v1.k8s.emberstack.com/reflection-allowed: "true"
          reflector.v1.k8s.emberstack.com/reflection-auto-enabled: "true"
      dataVolumeClaimSpec:
        accessModes:
        - ReadWriteOnce
        resources:
          requests:
            storage: 200Gi
      name: pgha1
      replicas: 1
      resources:
        requests:
          cpu: 500m
          memory: 3000Mi
      tolerations:
        - effect: NoSchedule
          key: indico.io/crunchy
          operator: Exists
    pgBackRestConfig:
      repos:
      - name: repo1
        volume:
          volumeClaimSpec:
            accessModes:
            - ReadWriteOnce
            resources:
              requests:
                storage: 200Gi
        schedules:
          full: 30 4 * * *
          incremental: 0 */1 * * *
    imagePullSecrets:
      - name: harbor-pull-secret
  postgres-metrics:
    enabled: false
  EOF
  ]
}



resource "helm_release" "ipa-pre-requisites" {
  depends_on = [
    time_sleep.wait_1_minutes_after_crds,
    helm_release.ipa-crds,
    data.vault_kv_secret_v2.zerossl_data,
    kubernetes_secret.azure_storage_key,
    kubernetes_config_map.azure_dns_credentials,
    kubernetes_service_account.workload_identity,
    kubernetes_namespace.indico,
    helm_release.crunchy-postgres
  ]

  verify           = false
  name             = "ipa-pre-reqs"
  create_namespace = true
  namespace        = var.ipa_namespace
  repository       = var.ipa_repo
  chart            = "ipa-pre-requisites"
  version          = var.ipa_pre_reqs_version
  wait             = false
  timeout          = "1800" # 30 minutes
  disable_webhooks = false

  values = [<<EOF

cluster:
  name: ${var.label}
  region: ${var.region}
  account: ${var.account}
  domain: ${var.domain_suffix}

rabbitmq:
  enabled: true

secrets:
  rabbitmq:
    create: true
  
  general:
    create: true

  clusterIssuer:
    zerossl:
      create: true
      eabEmail: devops-sa@indico.io
      eabKid: "${jsondecode(data.vault_kv_secret_v2.zerossl_data.data_json)["EAB_KID"]}"
      eabHmacKey: "${jsondecode(data.vault_kv_secret_v2.zerossl_data.data_json)["EAB_HMAC_KEY"]}"
     
apiModels:
  enabled: true
  nodeSelector:
    node_group: static-workers

external-dns:
  enabled: true
  logLevel: debug
  policy: sync
  txtOwnerId: "${var.label}-${var.region}"
  domainFilters:
    - ${var.base_domain}.

  provider: azure
  
  extraVolumes: 
    - name: azure-config
      configMap:
        name: dns-credentials-config

  extraVolumeMounts: 
    - name: azure-config
      mountPath: /etc/kubernetes/azure.json
      subPath: azure.json

  policy: sync
  sources:
    - service
    - ingress

cluster-autoscaler:
  enabled: false
      
storage:
  existingPVC: false
  ebsStorageClass:
    enabled: false
  indicoStorageClass:
    enabled: false
    name: azurefile
  pvcSpec:
    azureFile:
      readOnly: false
      secretName: ${kubernetes_secret.azure_storage_key.metadata.0.name}
      secretNamespace: ${var.ipa_namespace}
      shareName: ${var.fileshare_name}
    mountOptions:
      - dir_mode=0777
      - file_mode=0777
      - uid=0
      - gid=0
      - nobrl
      - nosharesock
    csi: null
    persistentVolumeReclaimPolicy: Retain
    volumeMode: Filesystem

crunchy-postgres:
  enabled: false
  postgres-data:
    openshift: true
    
aws-fsx-csi-driver:
  enabled: false
metrics-server:
  enabled: false
  EOF
  ]
}

resource "time_sleep" "wait_1_minutes_after_pre_reqs" {
  depends_on = [
    helm_release.ipa-pre-requisites,
    kubernetes_namespace.indico
  ]

  create_duration = "1m"
}
