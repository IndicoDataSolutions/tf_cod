resource "helm_release" "ipa-crds" {
  depends_on = [
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
    #extraArgs:
    #  - --dns01-recursive-nameservers-only
    #  - --dns01-recursive-nameservers='$#{data.azurerm_dns_zone.azure_zone.name_servers[0]}:53,$#{data.azurerm_dns_zone.azure_zone.name_servers[1]}:53,$#{dataazurerm_dns_zone.azure_zone.name_servers[2]}:53'
    #  - --acme-http01-solver-nameservers='$#{data.azurerm_dns_zone.azure_zone.name_servers[0]}:53,$#{data.azurerm_dns_zone.azure_zone.name_servers[1]}:53,$#{data.azurerm_dns_zone.azure_zone.name_servers[2]}:53'
     
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
  depends_on = [helm_release.ipa-crds]

  create_duration = "1m"
}

resource "helm_release" "crunchy-postgres" {
  count = var.is_openshift == true ? 1 : 0
  depends_on = [
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


resource "helm_release" "ipa-pre-requisites" {
  depends_on = [
    time_sleep.wait_1_minutes_after_crds,
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
    server: ${var.kubernetes_host}
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
            nvidia-device-plugin:
              enabled: ${!var.is_openshift}
            ${var.is_openshift ? "kafka-strimzi: {podSecurityContext: {fsGroup: 1001}}" : "#azure kafka-strmzi"}
            worker:
              autoscaling:
                authentication:
                  enabled: ${var.is_openshift}
                  authModes: bearer
                  authTrigger: keda-trigger-auth-prometheus
                serverAddress: ${local.prometheus_address}
                highmem:
                  serverAddress: ${local.prometheus_address}
            reloader:
              isOpenshift: ${var.is_openshift}
            aws-node-termination:
              enabled: false
            app-edge:
              openshift:
                enabled: ${var.is_openshift}
            rainbow-nginx:
              openshift:
                enabled: ${var.is_openshift}
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

resource "argocd_application" "ipa" {
  depends_on = [
    helm_release.ipa-pre-requisites,
    time_sleep.wait_1_minutes_after_pre_reqs,
    helm_release.cod-snapshot-restore,
    github_repository_file.smoketest-application-yaml,
    github_repository_file.argocd-application-yaml,
    helm_release.keda-monitoring
  ]

  count = var.argo_enabled == true && var.ipa_enabled == true ? 1 : 0

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
    server: ${var.kubernetes_host}
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
