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
    "userAssignedIdentityID" : "${module.cluster.kubelet_identity.client_id}"
  }
  EOF

  # https://docs.openshift.com/container-platform/4.10/nodes/pods/nodes-pods-autoscaling-custom.html
  prometheus_address = var.is_openshift ? "https://thanos-querier.openshift-monitoring.svc.cluster.local:9091" : "http://monitoring-kube-prometheus-prometheus.monitoring.svc.cluster.local:9090/prometheus"

}
resource "kubernetes_secret" "issuer-secret" {
  depends_on = [
    module.cluster
  ]

  metadata {
    name      = "acme-azuredns"
    namespace = "default"
    annotations = {
      "reflector.v1.k8s.emberstack.com/reflection-allowed"      = true
      "reflector.v1.k8s.emberstack.com/reflection-auto-enabled" = true
      "temporary.please.change/weaker-credentials-needed"       = true
    }
  }

  type = "Opaque"

  data = {
    "secret-access-key" = "foobar"
  }
}

#TODO: move to prereqs
resource "kubernetes_secret" "harbor-pull-secret" {
  depends_on = [
    module.cluster
  ]

  metadata {
    name      = "harbor-pull-secret"
    namespace = "default"
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
  depends_on = [
    module.cluster,
    kubernetes_secret.harbor-pull-secret,
    kubernetes_secret.issuer-secret
  ]

  verify           = false
  name             = "ipa-crds"
  create_namespace = true
  namespace        = "default"
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
    #dns01RecursiveNameserversOnly: true
    #dns01RecursiveNameservers: "$#{data.azurerm_dns_zone.domain.name_servers[0]}:53,$#{data.azurerm_dns_zone.domain.name_servers[1]}:53,$#{data.azurerm_dns_zone.domain.name_servers[2]}:53,$#{data.azurerm_dns_zone.domain.name_servers[3]}:53"

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
  aws-ebs-csi-driver:
    enabled: false
 EOF
  ]
}




resource "time_sleep" "wait_1_minutes_after_crds" {
  depends_on = [helm_release.ipa-crds]

  create_duration = "1m"
}



# Install the Machinesets now
resource "helm_release" "crunchy-postgres" {
  count = var.is_openshift == true ? 1 : 0
  depends_on = [
    module.cluster,
    helm_release.ipa-crds,
    time_sleep.wait_1_minutes_after_crds
  ]

  name             = "crunchy"
  create_namespace = true
  namespace        = "crunchy"
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

resource "azurerm_role_assignment" "external_dns" {
  count = var.is_azure == true && var.is_openshift == false && var.include_external_dns == true ? 1 : 0
  depends_on = [
    module.cluster
  ]

  scope                            = data.azurerm_dns_zone.domain.id
  role_definition_name             = "DNS Zone Contributor"
  principal_id                     = module.cluster.kubelet_identity.object_id
  skip_service_principal_aad_check = true
}

resource "kubernetes_secret" "azure_storage_key" {
  depends_on = [
    module.cluster
  ]
  metadata {
    name = "azure-storage-key"
  }

  data = {
    azurestorageaccountname = module.storage.storage_account_name
    azurestorageaccountkey  = module.storage.storage_account_primary_access_key
    AZURE_ACCOUNT_NAME      = module.storage.storage_account_name
    AZURE_ACCOUNT_KEY       = module.storage.storage_account_primary_access_key
    AZURE_CONTAINER         = module.storage.blob_store_name
  }
}

resource "kubernetes_config_map" "azure_dns_credentials" {
  count = var.include_external_dns == true ? 1 : 0

  depends_on = [
    module.cluster
  ]

  metadata {
    name = "dns-credentials-config"
  }

  data = {
    "azure.json" = var.is_openshift ? local.openshift_dns_credentials : local.azure_dns_credentials
  }
}

resource "helm_release" "ipa-pre-requisites" {
  depends_on = [
    time_sleep.wait_1_minutes_after_crds,
    module.cluster,
    module.storage,
    helm_release.ipa-crds,
    data.vault_kv_secret_v2.zerossl_data,
    kubernetes_secret.azure_storage_key,
    kubernetes_config_map.azure_dns_credentials,
    kubernetes_service_account.workload_identity
  ]

  verify           = false
  name             = "ipa-pre-reqs"
  create_namespace = true
  namespace        = "default"
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
  domain: ${var.domain_suffix}
  account: ${var.account}

rabbitmq:
  enabled: true
  rabbitmq:
    metrics:
      enabled: ${var.is_openshift}
      serviceMonitor:
        enabled: ${var.is_openshift}

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
     
clusterIssuer:
  additionalSolvers:
    - dns01:
        azureDNS:
          environment: AzurePublicCloud
          hostedZoneName: ${data.azurerm_dns_zone.domain.name}
          managedIdentity:
            clientID: ${module.cluster.kubelet_identity.client_id}
          resourceGroupName: ${var.common_resource_group}
          subscriptionID: ${split("/", data.azurerm_subscription.primary.id)[2]}
      selector:
        matchLabels:
          "acme.cert-manager.io/dns01-solver": "true"

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
    - ${var.account}.${var.domain_suffix}.

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
    name: "${local.indico_storage_class_name}"
  pvcSpec:
    azureFile:
      readOnly: false
      secretName: "azure-storage-key"
      secretNamespace: null
      shareName: ${module.storage.fileshare_name}
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
  enabled: ${!var.is_openshift}
  postgres-data:
    openshift: ${var.is_openshift}
    
aws-fsx-csi-driver:
  enabled: false
metrics-server:
  enabled: false
  EOF
  ]
}

resource "time_sleep" "wait_1_minutes_after_pre_reqs" {
  depends_on = [helm_release.ipa-pre-requisites]

  create_duration = "1m"
}

data "github_repository" "argo-github-repo" {
  count     = var.argo_enabled == true ? 1 : 0
  full_name = "${var.github_organization}/${var.argo_repo}"
}

resource "github_repository_file" "smoketest-application-yaml" {
  count = var.ipa_smoketest_enabled == true ? 1 : 0

  repository          = data.github_repository.argo-github-repo[0].name
  branch              = var.argo_branch
  file                = "${var.argo_path}/ipa_smoketest.yaml"
  commit_message      = var.message
  overwrite_on_create = true

  lifecycle {
    ignore_changes = [
      content
    ]
  }

  content = <<EOT
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ${local.argo_smoketest_app_name}
  finalizers:
    - resources-finalizer.argocd.argoproj.io
  labels:
    app: cod
    region: ${var.region}
    account: ${var.account}
    name: ${var.label}
  annotations:
    avp.kubernetes.io/path: tools/argo/data/ipa-deploy
    argocd.argoproj.io/sync-wave: "2"
spec:
  destination:
    server: ${module.cluster.kubernetes_host}
    namespace: default
  project: "${lower("${var.account}.${var.label}.${var.region}")}"
  syncPolicy:
    automated:
      prune: true
    syncOptions:
      - CreateNamespace=true
  source:
    chart: cod-smoketests
    repoURL: ${var.ipa_smoketest_repo}
    targetRevision: ${var.ipa_smoketest_version}
    plugin:
      name: argocd-vault-plugin-helm-values-expand-no-build
      env:
        - name: KUBE_VERSION
          value: "${var.k8s_version}"
          
        - name: RELEASE_NAME
          value: run
  
        - name: HELM_TF_COD_VALUES
          value: |
            prometheus:
              url: ${local.prometheus_address}

        - name: HELM_VALUES
          value: |
            image:
              tag: ${var.ipa_smoketest_container_tag}
            cronjob:
              enabled: ${var.ipa_smoketest_cronjob_enabled}
              schedule: "${var.ipa_smoketest_cronjob_schedule}"
            cluster:
              name: ${var.label}
              region: ${var.region}
              account: ${var.account}
            host: ${local.dns_name}
            slack:
              channel: ${var.ipa_smoketest_slack_channel}
            ${indent(12, base64decode(var.ipa_smoketest_values))} 
EOT
}


resource "github_repository_file" "argocd-application-yaml" {
  count = var.argo_enabled == true ? 1 : 0

  repository          = data.github_repository.argo-github-repo[0].name
  branch              = var.argo_branch
  file                = "${var.argo_path}/ipa_application.yaml"
  commit_message      = var.message
  overwrite_on_create = true

  lifecycle {
    ignore_changes = [
      content
    ]
  }

  content = <<EOT
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ${local.argo_app_name}
  finalizers:
    - resources-finalizer.argocd.argoproj.io
  labels:
    app: cod
    region: ${var.region}
    account: ${var.account}
    name: ${var.label}
  annotations:
    avp.kubernetes.io/path: tools/argo/data/ipa-deploy
spec:
  destination:
    server: ${module.cluster.kubernetes_host}
    namespace: default
  project: "${lower("${var.account}.${var.label}.${var.region}")}"
  syncPolicy:
    automated:
      prune: true
    syncOptions:
      - CreateNamespace=true
  source:
    chart: ipa
    repoURL: ${var.ipa_repo}
    targetRevision: ${var.ipa_version}
    plugin:
      name: argocd-vault-plugin-helm-values-expand-no-build
      env:
        - name: KUBE_VERSION
          value: "${var.k8s_version}"
          
        - name: RELEASE_NAME
          value: ipa
        
        - name: HELM_TF_COD_VALUES
          value: |
            readapi:
              annotations:
                "azure.workload.identity/inject-proxy-sidecar": "true"
                reloader.stakater.com/auto: "true"
              
              serviceAccountName: "workload-identity-storage-account"
              labels:
                "azure.workload.identity/use": "true"
                
            aws-node-termination:
              enabled: false 
            global:
              podLabels:
                "azure.workload.identity/use": "true"
              serviceAccountName: "workload-identity-storage-account"
            runtime-scanner:
              enabled: ${replace(lower(var.account), "indico", "") == lower(var.account) ? "false" : "true"}
              authentication:
                ingressUser: monitoring
                ingressPassword: ${random_password.monitoring-password.result}
        
        - name: HELM_VALUES
          value: |
            ${base64decode(var.ipa_values)}    
EOT
}

data "vault_kv_secret_v2" "zerossl_data" {
  mount = var.vault_mount_path
  name  = "zerossl"
}

output "zerossl" {
  sensitive = true
  value     = data.vault_kv_secret_v2.zerossl_data.data_json
}

resource "argocd_application" "ipa" {
  depends_on = [
    helm_release.ipa-pre-requisites,
    time_sleep.wait_1_minutes_after_pre_reqs,
    module.argo-registration,
    helm_release.cod-snapshot-restore,
    github_repository_file.smoketest-application-yaml,
    github_repository_file.argocd-application-yaml,
    helm_release.keda-monitoring
  ]

  count = var.ipa_enabled == true ? 1 : 0

  wait = true

  metadata {
    name      = lower("${var.account}-${var.region}-${var.label}-deploy-ipa")
    namespace = "argo"
    labels = {
      test = "true"
    }
  }

  spec {

    project = lower("${var.account}.${var.label}.${var.region}")

    source {
      plugin {
        name = "argocd-vault-plugin"
      }
      repo_url        = "https://github.com/IndicoDataSolutions/${var.argo_repo}.git"
      path            = var.argo_path
      target_revision = var.argo_branch
    }

    sync_policy {
      automated = {
        prune       = true
        self_heal   = false
        allow_empty = false
      }
    }

    destination {
      server    = "https://kubernetes.default.svc"
      namespace = "argo"
    }
  }

  timeouts {
    create = "30m"
    delete = "30m"
  }
}


# Create Argo Application YAML for each user supplied application


resource "github_repository_file" "custom-application-yaml" {
  for_each = var.argo_enabled == true ? var.applications : {}

  repository          = data.github_repository.argo-github-repo[0].name
  branch              = var.argo_branch
  file                = "${var.argo_path}/${each.value.name}_application.yaml"
  commit_message      = var.message
  overwrite_on_create = true

  #TODO:
  # this allows people to make edits to the file so we don't overwrite it.
  #lifecycle {
  #  ignore_changes = [
  #    content
  #  ]
  #}
  content = <<EOT
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ${lower("${var.account}-${var.region}-${var.label}-${each.value.name}")} 
  finalizers:
    - resources-finalizer.argocd.argoproj.io
  annotations:
     avp.kubernetes.io/path: ${each.value.vaultPath}
  labels:
    app: ${each.value.name}
    region: ${var.region}
    account: ${var.account}
    name: ${var.label}
spec:
  destination:
    server: ${module.cluster.kubernetes_host}
    namespace: ${each.value.namespace}
  project: "${lower("${var.account}.${var.label}.${var.region}")}"
  syncPolicy:
    automated:
      prune: true
    syncOptions:
      - CreateNamespace=${each.value.createNamespace}
  source:
    chart: ${each.value.chart}
    repoURL: ${each.value.repo}
    targetRevision: ${each.value.version}
    plugin:
      name: argocd-vault-plugin-helm-values-expand-no-build
      env:
        - name: KUBE_VERSION
          value: "${var.k8s_version}"
        - name: RELEASE_NAME
          value: ${each.value.name}
        - name: HELM_VALUES
          value: |
            ${indent(12, base64decode(each.value.values))}
EOT
}

