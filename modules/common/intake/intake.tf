locals {
  storage_class = var.on_prem_test == false ? "encrypted-gp2" : "nfs-client"

  alb_ipa_values = var.enable_waf == true ? (<<EOT
app-edge:
  alternateDomain: ""
  service:
    type: "NodePort"
    ports:
      http_port: 31755
      http_api_port: 31270
  nginx:
    httpPort: 8080
  aws-load-balancer-controller:
    enabled: true
    aws-load-balancer-controller:
      enabled: true
      clusterName: ${var.label}
    ingress:
      enabled: true
      useStaticCertificate: ${var.use_static_ssl_certificates}
      labels:
        indico.io/cluster: ${var.label}
      tls:
        - secretName: ${var.ssl_static_secret_name}
          hosts:
            - ${var.dns_name}
      alb:
        publicSubnets: ${join(",", var.public_subnet_ids)}
        wafArn: ${var.waf_arn}
        acmArn: ${var.acm_arn}
      service:
        name: app-edge
        port: 8080
      hosts:
        - host: ${var.dns_name}
          paths:
            - path: /
              pathType: Prefix
  EOT
    ) : (<<EOT
app-edge:
  alternateDomain: ""
  image:
    registry: ${var.local_registry_enabled ? "local-registry.${var.dns_name}" : "harbor.devops.indico.io"}/indico
EOT 
  )

  efs_values = var.include_efs == true ? [<<EOF
  storage:
    pvcSpec:
      volumeMode: Filesystem
      mountOptions: []
      csi:
        driver: efs.csi.aws.com
        volumeHandle: ${var.efs_filesystem_id}
 EOF
  ] : []
  fsx_values = var.include_fsx == true ? [<<EOF
  storage:
    pvcSpec:
      csi:
        driver: fsx.csi.aws.com
        volumeAttributes:
          dnsname: ${var.fsx_rwx.dns_name}
          mountname: ${var.fsx_rwx.mount_name}
        volumeHandle: ${var.fsx_rwx.id}
 EOF
  ] : []
  storage_spec = var.include_fsx == true ? local.fsx_values : local.efs_values

  local_registry_tf_cod_values = var.local_registry_enabled == true ? (<<EOT
global:
  imagePullSecrets: 
    - name: local-pull-secret
    - name: harbor-pull-secret
  image:
    registry: local-registry.${var.dns_name}/indico

app-edge:
  image:
    registry: local-registry.${var.dns_name}/indico
  EOT
    ) : (<<EOT
# not using local_registry
  EOT
  )

  runtime_scanner_ingress_values = var.use_static_ssl_certificates == true ? (<<EOT
ingress:
  enabled: true
  useStaticCertificate: true
  className: "nginx"
  annotations:
    nginx.ingress.kubernetes.io/auth-type: basic
    nginx.ingress.kubernetes.io/auth-realm: 'Authentication Required - alternate'
    nginx.ingress.kubernetes.io/auth-secret: runtime-scanner-auth
  
  useDefaultResolver: true
  labels: {}
  hosts:
    - host: scan
      paths:
        - path: /
          pathType: ImplementationSpecific
  tls: 
    - secretName: ${var.ssl_static_secret_name}
      hosts:
        - scan
  EOT
    ) : (<<EOT
ingress:
  enabled: true
  className: "nginx"
  annotations:
    cert-manager.io/cluster-issuer: zerossl
EOT
  )
}

data "github_repository" "argo-github-repo" {
  count     = var.argo_enabled == true ? 1 : 0
  full_name = "IndicoDataSolutions/${var.argo_repo}"
}

resource "github_repository_file" "pre-reqs-values-yaml" {
  count               = var.argo_enabled == true ? 1 : 0
  repository          = data.github_repository.argo-github-repo[0].name
  branch              = var.argo_branch
  file                = "${var.argo_path}/helm/pre-reqs-values.values"
  commit_message      = var.message
  overwrite_on_create = true

  lifecycle {
    ignore_changes = [
      content
    ]
  }
  content = base64decode(var.pre-reqs-values-yaml-b64)
}

data "github_repository_file" "data-pre-reqs-values" {
  count = var.argo_enabled == true ? 1 : 0

  depends_on = [
    github_repository_file.pre-reqs-values-yaml
  ]
  repository = data.github_repository.argo-github-repo[0].name
  branch     = var.argo_branch
  file       = var.argo_path == "." ? "helm/pre-reqs-values.values" : "${var.argo_path}/helm/pre-reqs-values.values"
}

resource "helm_release" "ipa-pre-requisites" {
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

  values = concat(local.storage_spec, [<<EOF

cluster:
  cloudProvider: aws
  name: ${var.label}
  region: ${var.region}
  domain: indico.io
  account: ${var.aws_account}
  argoRepo: ${var.argo_repo}
  argoBranch: ${var.argo_branch}
  argoPath: ${var.argo_path}
  ipaVersion: ${var.ipa_version}
  ipaPreReqsVersion: ${var.ipa_pre_reqs_version}

secrets:
  rabbitmq:
    create: true
  general:
    create: true

crunchy-postgres:
  enabled: true
  postgres-data:
    enabled: true
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
        storageClassName: ${local.storage_class}
        accessModes:
        - ReadWriteOnce
        resources:
          requests:
            storage: 200Gi
      name: pgha1
      replicas: ${var.az_count}
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
        repo1-path: /pgbackrest/postgres-data/repo1
        repo1-retention-full: '5'
        repo1-s3-key-type: auto
        repo1-s3-kms-key-id: "${var.key_arn}"
        repo1-s3-role: ${var.s3_role_id}
      repos:
      - name: repo1
        s3:
          bucket: ${var.pgbackup_s3_bucket_name}
          endpoint: s3.${var.region}.amazonaws.com
          region: ${var.region}
        schedules:
          full: 30 4 * * 0 # Full backup weekly at 4:30am Sunday
          differential: 0 0 * * * # Diff backup daily at midnight
      jobs:
        resources:
          requests:
            cpu: 1000m
            memory: 3000Mi
    imagePullSecrets:
      - name: harbor-pull-secret
  postgres-metrics:
    enabled: false
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
                - postgres-metrics
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
        storageClassName: ${local.storage_class}
        accessModes:
        - ReadWriteOnce
        resources:
          requests:
            storage: 100Gi
      name: pgha1
      replicas: 2
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
        repo1-path: /pgbackrest/postgres-metrics/repo1
        repo1-retention-full: '5'
        repo1-s3-key-type: auto
        repo1-s3-kms-key-id: "${var.key_arn}"
        repo1-s3-role: ${var.s3_role_id}
      repos:
      - name: repo1
        s3:
          bucket: ${var.pgbackup_s3_bucket_name}
          endpoint: s3.${var.region}.amazonaws.com
          region: ${var.region}
        schedules:
          full: 30 4 * * 0 # Full backup weekly at 4:30am Sunday
          differential: 0 0 * * * # Diff backup daily at midnight
      jobs:
        resources:
          requests:
            cpu: 1000m
            memory: 3000Mi
    imagePullSecrets:
      - name: harbor-pull-secret
aws-load-balancer-controller:
  enabled: ${var.use_acm}
  aws-load-balancer-controller:
    clusterName: ${var.label}
    vpcId: ${local.network[0].indico_vpc_id}
    region: ${var.region}
EOF
    ,
    <<EOT
${var.argo_enabled == true ? data.github_repository_file.data-pre-reqs-values[0].content : ""}
EOT
  ])
}

resource "time_sleep" "wait_1_minutes_after_pre_reqs" {
  depends_on = [helm_release.ipa-pre-requisites]

  create_duration = "1m"
}



resource "github_repository_file" "alb-values-yaml" {
  count               = var.argo_enabled == true ? 1 : 0
  repository          = data.github_repository.argo-github-repo[0].name
  branch              = var.argo_branch
  file                = "${var.argo_path}/helm/alb.values"
  commit_message      = var.message
  overwrite_on_create = true

  lifecycle {
    ignore_changes = [
      content
    ]
  }

  content = local.alb_ipa_values
}

resource "github_repository_file" "argocd-application-yaml" {
  count               = var.argo_enabled == true ? 1 : 0
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
  name: ${lower("${var.aws_account}.${var.region}.${var.label}-ipa")}
  finalizers:
    - resources-finalizer.argocd.argoproj.io
  labels:
    app: cod
    region: ${var.region}
    account: ${var.aws_account}
    name: ${var.label}
  annotations:
    avp.kubernetes.io/path: tools/argo/data/ipa-deploy
    argocd.argoproj.io/sync-wave: "-2"
spec:
  ignoreDifferences:
    - group: apps
      jsonPointers:
        - /spec/replicas
      kind: Deployment
  destination:
    server: ${var.kubernetes_host}
    namespace: default
  project: ${var.argo_project_name}
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
            global:
              image:
                registry: ${var.local_registry_enabled ? "local-registry.${var.dns_name}" : "harbor.devops.indico.io"}/indico
            ${indent(12, local.local_registry_tf_cod_values)}
            runtime-scanner:
              enabled: ${replace(lower(var.aws_account), "indico", "") == lower(var.aws_account) ? "false" : "true"}
              authentication:
                ingressUser: monitoring
                ingressPassword: ${var.monitoring_password}
                ${indent(14, local.runtime_scanner_ingress_values)} 
            ${indent(12, local.alb_ipa_values)}         

        - name: HELM_VALUES
          value: |
            ${base64decode(var.ipa_values)}    
EOT
}


resource "argocd_application" "ipa" {
  depends_on = [
    time_sleep.wait_1_minutes_after_pre_reqs,
    kubernetes_job.snapshot-restore-job,
    github_repository_file.argocd-application-yaml,
  ]

  count = var.argo_enabled == true ? 1 : 0

  wait = true

  metadata {
    name      = lower("${var.aws_account}-${var.region}-${var.label}-deploy-ipa")
    namespace = var.argo_namespace
    labels = {
      test = "true"
    }
  }

  spec {
    project = module.argo-registration[0].argo_project_name

    source {
      repo_url        = "https://github.com/IndicoDataSolutions/${var.argo_repo}.git"
      path            = var.argo_path
      target_revision = var.argo_branch
      directory {
        exclude = "cod.yaml"
        recurse = false
        jsonnet {
        }
      }
    }
    sync_policy {
      automated {
        prune       = true
        self_heal   = false
        allow_empty = false
      }
    }

    destination {
      #server    = "https://kubernetes.default.svc"
      name      = "in-cluster"
      namespace = var.argo_namespace
    }
  }

  timeouts {
    create = "30m"
    delete = "30m"
  }
}

