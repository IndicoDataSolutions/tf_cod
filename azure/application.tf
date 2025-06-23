locals {
  openshift_dns_credentials = <<EOF
  {
  "tenantId" : "${data.azurerm_client_config.current.tenant_id}",
  "subscriptionId" : "${split("/", data.azurerm_subscription.primary.id)[2]}",
  "resourceGroup" : "${var.common_resource_group}",
  "aadClientId": "${var.use_workload_identity == true ? azuread_application.workload_identity.0.application_id : ""}",
  "aadClientSecret": "${var.use_workload_identity == true ? azuread_application_password.workload_identity.0.value : ""}"
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
    namespace = "indico"
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
    namespace = "indico"
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

data "vault_kv_secret_v2" "harbor-api-token" {
  count = var.argo_enabled == true ? 1 : 0
  mount = "tools/argo"
  name  = "harbor-api"
}

module "secrets-operator-setup" {
  depends_on = [
    module.cluster
  ]
  count           = var.secrets_operator_enabled == true ? 1 : 0
  source          = "../modules/common/vault-secrets-operator-setup"
  vault_address   = var.vault_address
  account         = var.account
  region          = var.region
  name            = var.label
  kubernetes_host = module.cluster.kubernetes_host
}

resource "kubernetes_namespace" "indico" {
  metadata {
    name = "indico"
  }
}

locals {
  indico_crds_values = [<<EOF
migrations:
  vaultSecretsOperator:
    updateCRDs: ${var.secrets_operator_enabled}
aws-ebs-csi-driver:
  enabled: false
cert-manager: 
  enabled: true
  crds:
    enabled: true   
  nodeSelector:
    kubernetes.io/os: linux
  webhook:
    nodeSelector:
      kubernetes.io/os: linux
  cainjector:
    nodeSelector:
      kubernetes.io/os: linux
migrations-operator:
  enabled: ${var.ipa_enabled || var.insights_enabled}
  image:
    repository: ${var.image_registry}/indico/migrations-operator
  controllerImage:
    repository: ${var.image_registry}/indico/migrations-controller
    kubectlImage: ${var.image_registry}/indico/migrations-controller-kubectl
crunchy-pgo:
  enabled: ${var.ipa_enabled || var.insights_enabled}
minio:
  enabled: ${var.insights_enabled || var.minio_enabled}
vault-secrets-operator:
  enabled: ${var.secrets_operator_enabled}
  controller: 
    imagePullSecrets:
      - name: harbor-pull-secret
    kubeRbacProxy:
      image:
        repository: ${var.image_registry}/quay.io/brancz/kube-rbac-proxy
      resources:
        limits:
          cpu: 500m
          memory: 1024Mi
        requests:
          cpu: 500m
          memory: 512Mi
    manager:
      image:
        repository: ${var.image_registry}/docker.io/hashicorp/vault-secrets-operator
      resources:
        limits:
          cpu: 500m
          memory: 1024Mi
        requests:
          cpu: 500m
          memory: 512Mi
  defaultAuthMethod:
    enabled: true
    namespace: default
    method: kubernetes
    mount: ${var.secrets_operator_enabled == true ? module.secrets-operator-setup[0].vault_mount_path : "unused-mount"}
    kubernetes:
      role: ${var.secrets_operator_enabled == true ? module.secrets-operator-setup[0].vault_auth_role_name : "unused-role"}
      tokenAudiences: ["vault"]
      serviceAccount: ${var.secrets_operator_enabled == true ? module.secrets-operator-setup[0].vault_auth_service_account_name : "vault-sa"}
  defaultVaultConnection:
    enabled: true
    address: ${var.vault_address}
    skipTLSVerify: false
    spec:
    template:
      spec:
        containers:
        - name: manager
          args:
          - "--client-cache-persistence-model=direct-encrypted"
external-secrets:
  enabled: true
  installCRDs: true
  image:
    repository: ${var.image_registry}/ghcr.io/external-secrets/external-secrets
  webhook:
    image:
      repository: ${var.image_registry}/ghcr.io/external-secrets/external-secrets
  certController:
    image:
      repository: ${var.image_registry}/ghcr.io/external-secrets/external-secrets
  EOF
  ]

  indico_pre_reqs_values = [<<EOF
global:
  host: ${local.dns_name}
  image:
    registry: ${var.image_registry}
storage:
  ebsStorageClass:
    enabled: false
secrets:
  rabbitmq:
    create: true
  general:
    create: true
  clusterIssuer:
    zerossl:
      create: ${var.enable_custom_cluster_issuer == false ? true : false}
      eabEmail: devops-sa@indico.io
      eabKid: "${jsondecode(data.vault_kv_secret_v2.zerossl_data.data_json)["EAB_KID"]}"
      eabHmacKey: "${jsondecode(data.vault_kv_secret_v2.zerossl_data.data_json)["EAB_HMAC_KEY"]}"
    letsencrypt:
      create: true
clusterIssuer:
  additionalSolvers:
    - dns01:
        azureDNS:
          environment: AzurePublicCloud
          hostedZoneName: ${local.base_domain}
          managedIdentity:
            clientID: ${module.cluster.kubelet_identity.client_id}
          resourceGroupName: ${var.common_resource_group}
          subscriptionID: ${split("/", data.azurerm_subscription.primary.id)[2]}
      selector:
        matchLabels:
          "acme.cert-manager.io/dns01-solver": "true"

aws-efs-csi-driver:
  enabled: false
aws-for-fluent-bit:
  enabled: false
aws-fsx-csi-driver:
  enabled: false
aws-load-balancer-controller:
  enabled: false
cluster-autoscaler:
  enabled: false
external-dns:
  enabled: ${var.enable_external_dns}
  logLevel: debug
  policy: sync
  txtOwnerId: "${var.label}-${var.region}"
  domainFilters:
    - ${var.account}.${var.domain_suffix}.

  provider:
    name: azure
  
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
ingress-nginx:
  enabled: ${local.kube_prometheus_stack_enabled}
  rbac:
    create: true
  controller:
    service:
      annotations:
        service.beta.kubernetes.io/azure-load-balancer-health-probe-request-path: /healthz
  admissionWebhooks:
    patch:
      nodeSelector.beta.kubernetes.io/os: linux
    controller:
      service:
        annotations:
          service.beta.kubernetes.io/azure-load-balancer-health-probe-request-path: /healthz
  authentication:
    ingressUsername: monitoring
    ingressPassword: ${random_password.monitoring-password.result}
  defaultBackend:
    nodeSelector.beta.kubernetes.io/os: linux
reflector:
  image:
    repository: ${var.image_registry}/docker.io/emberstack/kubernetes-reflector
  EOF
  ]

  monitoring_values = var.monitoring_enabled ? concat([<<EOF
global:
  host: "${local.dns_name}"
prometheus-postgres-exporter:
  enabled: false
authentication:
  ingressUsername: monitoring
  ingressPassword: ${random_password.monitoring-password.result}
${local.alerting_configuration_values}
keda:
  enabled: ${var.monitoring_enabled}
  global:
    image:
      registry: "${var.image_registry}/ghcr.io"
  imagePullSecrets:
    - name: harbor-pull-secret
  resources:
    operator:
      requests:
        memory: 512Mi
      limits:
        memory: 4Gi
  crds:
    install: true
  
  podAnnotations:
    keda:
      prometheus.io/scrape: "true"
      prometheus.io/path: "/metrics"
      prometheus.io/port: "8080"
    metricsAdapter: 
      prometheus.io/scrape: "true"
      prometheus.io/path: "/metrics"
      prometheus.io/port: "9022"
  prometheus:
    metricServer:
      enabled: true
      podMonitor:
        enabled: true
    operator:
      enabled: true
      podMonitor:
        enabled: true
kube-prometheus-stack:
${local.kube_prometheus_stack_values}
metrics-server:
  enabled: false
opentelemetry-operator:
  enabled: ${var.monitoring_enabled}
  testFramework:
    image:
      repository: ${var.image_registry}/docker.io/library/busybox
  kubeRBACProxy:
    image:
      repository: ${var.image_registry}/quay.io/brancz/kube-rbac-proxy
  manager:
    image:
      repository: ${var.image_registry}/ghcr.io/open-telemetry/opentelemetry-operator/opentelemetry-operator
    collectorImage:
      repository: ${var.image_registry}/docker.io/otel/opentelemetry-collector-contrib
opentelemetry-collector:
  enabled: true
  imagePullSecrets:
    - name: harbor-pull-secret
  image:
    repository: ${var.image_registry}/docker.io/otel/opentelemetry-collector-contrib
  fullnameOverride: "collector-collector"
  mode: deployment
  tolerations:
  - effect: NoSchedule
    key: indico.io/monitoring
    operator: Exists
  nodeSelector:
    node_group: monitoring-workers
  ports:
    jaeger-compact:
      enabled: false
    jaeger-thrift:
      enabled: false
    jaeger-grpc:
      enabled: false
    zipkin:
      enabled: false

  config:
    receivers:
      jaeger: null
      prometheus: null
      zipkin: null
    exporters:
      otlp:
        endpoint: monitoring-tempo.monitoring.svc:4317
        tls:
          insecure: true
    service:
      pipelines:
        traces:
          receivers:
            - otlp
          processors:
            - batch
          exporters:
            - otlp
        metrics: null
        logs: null
sql-exporter:
  enabled: ${var.ipa_enabled}
  image:
    repository: '${var.image_registry}/dockerhub-proxy/burningalchemist/sql_exporter'
  EOF
    ], [<<EOF
${local.private_dns_config}
  EOF
  ]) : []
}

module "indico-common" {
  depends_on = [
    module.cluster,
    time_sleep.wait_1_minutes_after_cluster,
    module.secrets-operator-setup
  ]
  source                           = "../modules/common/indico-common"
  argo_enabled                     = var.argo_enabled
  github_repo_name                 = var.argo_repo
  github_repo_branch               = var.argo_branch
  github_file_path                 = var.argo_path
  github_commit_message            = var.message
  helm_registry                    = var.ipa_repo
  namespace                        = "indico"
  indico_crds_version              = var.indico_crds_version
  indico_crds_values_yaml_b64      = var.indico-crds-values-yaml-b64
  indico_crds_values_overrides     = local.indico_crds_values
  indico_pre_reqs_version          = var.indico_pre_reqs_version
  indico_pre_reqs_values_overrides = local.indico_pre_reqs_values
  indico_pre_reqs_values_yaml_b64  = var.indico-pre-reqs-values-yaml-b64
  monitoring_enabled               = var.monitoring_enabled
  monitoring_values                = local.monitoring_values
  monitoring_version               = var.monitoring_version
}

resource "time_sleep" "wait_1_minutes_after_cluster" {
  depends_on = [module.cluster]

  create_duration = "1m"
}

# Install the Machinesets now
resource "helm_release" "crunchy-postgres" {
  count = var.is_openshift == true ? 1 : 0
  depends_on = [
    module.cluster,
    module.indico-common
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
          cpu: 1000m
          memory: 3000Mi
      tolerations:
        - effect: NoSchedule
          key: indico.io/crunchy
          operator: Exists
    pgBackRestConfig:
      global:
        archive-timeout: '10000'
        repo1-retention-full: '5'
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
          full: 30 4 * * 0 # Full backup weekly at 4:30am Sunday
          differential: 0 0 * * * # Diff backup daily at midnight
    imagePullSecrets:
      - name: harbor-pull-secret
  postgres-metrics:
    enabled: false
  EOF
  ]
}

resource "azurerm_role_assignment" "external_dns" {
  count = var.is_azure == true && var.is_openshift == false && var.private_dns_zone != true ? 1 : 0
  depends_on = [
    module.cluster
  ]
  scope                            = data.azurerm_dns_zone.domain.0.id
  role_definition_name             = "DNS Zone Contributor"
  principal_id                     = module.cluster.kubelet_identity.object_id
  skip_service_principal_aad_check = true
}

resource "kubernetes_secret" "azure_storage_key" {
  depends_on = [
    module.cluster,
    time_sleep.wait_1_minutes_after_cluster
  ]
  metadata {
    name      = "azure-storage-key"
    namespace = "indico"
    annotations = {
      "reflector.v1.k8s.emberstack.com/reflection-allowed"      = true
      "reflector.v1.k8s.emberstack.com/reflection-auto-enabled" = true
    }
  }

  data = {
    AZURE_CLIENT_ID         = module.cluster.kubelet_identity.client_id
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
    module.cluster,
    time_sleep.wait_1_minutes_after_cluster
  ]

  metadata {
    name      = "dns-credentials-config"
    namespace = "indico"
  }

  data = {
    "azure.json" = var.is_openshift ? local.openshift_dns_credentials : local.azure_dns_credentials
  }
}


resource "kubectl_manifest" "custom-cluster-issuer" {
  count = var.enable_custom_cluster_issuer == true ? 1 : 0
  depends_on = [
    module.cluster,
    module.storage,
    module.indico-common,
    time_sleep.wait_1_minutes_after_cluster,
    data.vault_kv_secret_v2.zerossl_data,
    kubernetes_secret.azure_storage_key,
    kubernetes_config_map.azure_dns_credentials,
    kubernetes_service_account.workload_identity,
  ]
  yaml_body = <<YAML
    apiVersion: cert-manager.io/v1
    kind: ClusterIssuer
    metadata:
      name: zerossl
    spec:
      ${indent(6, var.custom_cluster_issuer_spec)} 
  YAML
}

locals {
  ipa_pre_reqs_values = [<<EOF
cluster:
  cloudProvider: azure
  name: ${var.label}
  region: ${var.region}
  domain: ${var.domain_suffix}
  account: ${var.account}
  argoRepo: ${var.argo_repo}
  argoBranch: ${var.argo_branch}
  argoPath: ${var.argo_path}
  ipaVersion: ${var.ipa_version}
  ipaPreReqsVersion: ${var.ipa_pre_reqs_version}
  ipaCrdsVersion: ${var.ipa_crds_version}

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

rabbitmq:
  enabled: true
  rabbitmq:
    metrics:
      enabled: true
      serviceMonitor:
        enabled: true

apiModels:
  enabled: true
  nodeSelector:
    node_group: static-workers

crunchy-postgres:
  enabled: ${!var.is_openshift}
  metadata:
    annotations:
      reflector.v1.k8s.emberstack.com/reflection-allowed-namespaces: "default,indico,monitoring"
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
        reflector.v1.k8s.emberstack.com/reflection-allowed-namespaces: "default,indico,monitoring"
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
    global:
      archive-timeout: '10000'
      repo1-path: /pgbackrest/postgres-data/repo1
      repo1-retention-full: '5'
      repo1-azure-account: ${module.storage.storage_account_name}
      repo1-azure-key: ${module.storage.storage_account_primary_access_key}
    repos:
    - name: repo1
      azure:
        container: " ${module.storage.crunchy_backup_name}"
      schedules:
        full: 30 4 * * *
        incremental: 0 0 * * *
    jobs:
      resources:
        requests:
          cpu: 1000m
          memory: 3000Mi
  EOF
  ]

  intake_values = <<EOF
nvidia-device-plugin:
  nvidia-device-plugin:
    compatWithCPUManager: True
readapi:
  annotations:
    reloader.stakater.com/auto: "true"
  serviceAccountName: "workload-identity-storage-account"
  labels:
    "azure.workload.identity/use": "true"
  secretRefs:
    - indico-static-secrets
    - indico-generated-secrets
    - rabbitmq
    - azure-storage-key
aws-node-termination:
  enabled: false 
app-edge:
  cspApprovedSources:
    - ${module.storage.storage_account_name}.blob.core.windows.net
global:
  podLabels:
    "azure.workload.identity/use": "true"
  serviceAccountName: "workload-identity-storage-account"
runtime-scanner:
  enabled: ${replace(lower(var.account), "indico", "") == lower(var.account) ? "false" : "true"}
  authentication:
    ingressUser: monitoring
    ingressPassword: ${random_password.monitoring-password.result}
  EOF
}

module "intake" {
  depends_on = [
    module.indico-common
  ]
  source                            = "../modules/common/intake"
  count                             = var.ipa_enabled ? 1 : 0
  argo_enabled                      = var.argo_enabled
  github_repo_name                  = var.argo_repo
  github_repo_branch                = var.argo_branch
  github_file_path                  = var.argo_path
  github_commit_message             = var.message
  helm_registry                     = var.ipa_repo
  namespace                         = "default"
  ipa_pre_reqs_version              = var.ipa_pre_reqs_version
  pre_reqs_values_yaml_b64          = var.pre-reqs-values-yaml-b64
  ipa_pre_reqs_values_overrides     = local.ipa_pre_reqs_values
  account                           = var.account
  region                            = var.region
  label                             = var.label
  argo_application_name             = lower("${var.account}.${var.region}.${var.label}-ipa")
  vault_path                        = "tools/argo/data/ipa-deploy"
  argo_server                       = module.cluster.kubernetes_host
  argo_project_name                 = module.argo-registration[0].argo_project_name
  intake_version                    = var.ipa_version
  k8s_version                       = var.k8s_version
  intake_values_terraform_overrides = local.intake_values
  intake_values_overrides           = var.ipa_values
}

data "github_repository" "argo-github-repo" {
  count     = var.argo_enabled == true ? 1 : 0
  full_name = "${var.github_organization}/${var.argo_repo}"
}

locals {
  smoketests_values = <<EOF
  cluster:
    account: ${var.account}
    region: ${var.region}
    name: ${var.label}
  host: ${local.dns_name}
  slack:
    channel: ${var.ipa_smoketest_slack_channel}
  prometheus:
    url: ${local.prometheus_address}
  ${indent(4, base64decode(var.ipa_smoketest_values))}
  EOF
}

module "intake_smoketests" {
  depends_on = [
    module.intake
  ]
  count                  = var.ipa_smoketest_enabled && var.ipa_enabled ? 1 : 0
  source                 = "../modules/common/application-deployment"
  account                = var.account
  region                 = var.region
  label                  = var.label
  namespace              = "default"
  argo_enabled           = var.argo_enabled
  github_repo_name       = var.argo_repo
  github_repo_branch     = var.argo_branch
  github_file_path       = "${var.argo_path}/ipa_smoketest.yaml"
  github_commit_message  = var.message
  argo_application_name  = local.argo_smoketest_app_name
  argo_vault_plugin_path = "tools/argo/data/ipa-deploy"
  argo_server            = module.cluster.kubernetes_host
  argo_project_name      = var.argo_enabled ? module.argo-registration[0].argo_project_name : ""
  chart_name             = "cod-smoketests"
  chart_repo             = var.ipa_smoketest_repo
  chart_version          = var.ipa_smoketest_version
  k8s_version            = var.k8s_version
  release_name           = "run"
  terraform_helm_values  = ""
  helm_values            = indent(10, trimspace(local.smoketests_values))
}

resource "random_password" "minio-password" {
  count   = var.insights_enabled ? 1 : 0
  length  = 16
  special = false
}

locals {
  insights_pre_reqs_values = [<<EOF
crunchy-postgres:
  enabled: ${!var.is_openshift}
  name: postgres-insights
  metadata:
    annotations:
      reflector.v1.k8s.emberstack.com/reflection-allowed-namespaces: "insights,indico,monitoring"
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
              - postgres-insights
            - key: postgres-operator.crunchydata.com/instance-set
              operator: In
              values:
              - pgha2
          topologyKey: kubernetes.io/hostname
    metadata:
      annotations:
        reflector.v1.k8s.emberstack.com/reflection-allowed: "true"
        reflector.v1.k8s.emberstack.com/reflection-auto-enabled: "true"
        reflector.v1.k8s.emberstack.com/reflection-allowed-namespaces: "insights,indico,monitoring"
    dataVolumeClaimSpec:
      accessModes:
      - ReadWriteOnce
      resources:
        requests:
          storage: 200Gi
    name: pgha2
    replicas: 1
    resources:
      requests:
        cpu: 1000m
        memory: 3000Mi
    tolerations:
      - effect: NoSchedule
        key: indico.io/crunchy
        operator: Exists
  pgBackRestConfig:
    global:
      archive-timeout: '10000'
      repo2-path: /pgbackrest/postgres-data/repo2
      repo2-retention-full: '5'
      repo2-azure-account: ${module.storage.storage_account_name}
      repo2-azure-key: ${module.storage.storage_account_primary_access_key}
    repos:
    - name: repo2
      azure:
        container: " ${module.storage.crunchy_backup_name}"
      schedules:
        full: 30 4 * * *
        incremental: 0 */1 * * *
    jobs:
      resources:
        requests:
          cpu: 1000m
          memory: 3000Mi
  monitoring: true
  users:
    - name: indico
      options: "SUPERUSER"
      databases:
        - aqueduct
        - ask_my_collection
        - lagoon
        - noct
ingress:
  useStaticCertificate: false
  secretName: indico-ssl-static-cert
minio:
  createStorageClass: false
  topology:
    storageClassName: default
  storage:
    accessKey: insights
    secretKey: ${var.insights_enabled ? random_password.minio-password[0].result : ""}
  EOF
  ]

  insights_values = <<EOF
global:
  host: ${var.label}.${var.region}.indico-dev.indico.io
  EOF
}

module "insights" {
  depends_on = [
    module.indico-common
  ]
  source                              = "../modules/common/insights"
  count                               = var.insights_enabled ? 1 : 0
  argo_enabled                        = var.argo_enabled
  github_repo_name                    = var.argo_repo
  github_repo_branch                  = var.argo_branch
  github_file_path                    = var.argo_path
  github_commit_message               = var.message
  helm_registry                       = var.ipa_repo
  namespace                           = "insights"
  ins_pre_reqs_version                = var.insights_pre_reqs_version
  pre_reqs_values_yaml_b64            = var.insights-pre-reqs-values-yaml-b64
  ins_pre_reqs_values_overrides       = local.insights_pre_reqs_values
  account                             = var.account
  region                              = var.region
  label                               = var.label
  argo_application_name               = lower("${var.account}.${var.region}.${var.label}-insights")
  vault_path                          = "tools/argo/data/ipa-deploy"
  argo_server                         = module.cluster.kubernetes_host
  argo_project_name                   = module.argo-registration[0].argo_project_name
  insights_version                    = var.insights_version
  k8s_version                         = var.k8s_version
  insights_values_terraform_overrides = local.insights_values
  insights_values_overrides           = var.insights_values
}

# And we can install any additional helm charts at this point as well
module "additional_application" {
  depends_on = [
    module.indico-common
  ]

  for_each = var.applications

  source                 = "../modules/common/application-deployment"
  account                = var.account
  region                 = var.region
  label                  = var.label
  namespace              = each.value.namespace
  argo_enabled           = var.argo_enabled
  github_repo_name       = var.argo_repo
  github_repo_branch     = var.argo_branch
  github_file_path       = "${var.argo_path}/${each.value.name}_application.yaml"
  github_commit_message  = var.message
  argo_application_name  = lower("${var.account}-${var.region}-${var.label}-${each.value.name}")
  argo_vault_plugin_path = each.value.vaultPath
  argo_server            = module.cluster.kubernetes_host
  argo_project_name      = var.argo_enabled ? module.argo-registration[0].argo_project_name : ""
  chart_name             = each.value.chart
  chart_repo             = each.value.repo
  chart_version          = each.value.version
  k8s_version            = var.k8s_version
  release_name           = each.value.name
  terraform_helm_values  = ""
  helm_values            = trimspace(base64decode(each.value.values))
}

data "vault_kv_secret_v2" "zerossl_data" {
  mount = local.customer_vault_mount_path
  name  = "zerossl"
}

output "zerossl" {
  sensitive = true
  value     = data.vault_kv_secret_v2.zerossl_data.data_json
}

resource "argocd_application" "ipa" {
  depends_on = [
    module.intake,
    module.insights,
    module.argo-registration,
    helm_release.cod-snapshot-restore
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
      repo_url        = "https://github.com/IndicoDataSolutions/${var.argo_repo}.git"
      path            = var.argo_path
      target_revision = var.argo_branch
      directory {
        recurse = false
        jsonnet {
        }
      }
    }

    sync_policy {
      automated {
        prune       = true
        self_heal   = true
        allow_empty = false
      }
      sync_options = [
        "ServerSideApply=true",
        "CreateNamespace=true"
      ]
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

resource "null_resource" "wait-for-tf-cod-chart-build" {
  count = var.argo_enabled == true ? 1 : 0

  depends_on = [
    module.intake,
    module.indico-common
  ]

  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    environment = {
      HARBOR_API_TOKEN = jsondecode(data.vault_kv_secret_v2.harbor-api-token[0].data_json)["bearer_token"]
    }
    command = "${path.module}/validate_chart.sh terraform-smoketests 0.1.1-${data.external.git_information.result.branch}-${substr(data.external.git_information.result.sha, 0, 8)}"
  }
}
