locals {
  #need to get the root of alternate_domain
  the_splits            = local.dns_name != "" ? split(".", local.dns_name) : split(".", "test.domain.com")
  the_length            = length(local.the_splits)
  the_tld               = local.the_splits[local.the_length - 1]
  the_domain            = local.the_splits[local.the_length - 2]
  alternate_domain_root = join(".", [local.the_domain, local.the_tld])

  enable_external_dns = var.use_static_ssl_certificates == false ? true : false
  efs_values = var.include_efs == true ? [<<EOF
  aws-fsx-csi-driver:
    enabled: false
  aws-efs-csi-driver:
    enabled: true
  storage:
    pvcSpec:
      volumeMode: Filesystem
      mountOptions: []
      csi:
        driver: efs.csi.aws.com
        volumeHandle: ${module.efs-storage[0].efs_filesystem_id}
    indicoStorageClass:
      enabled: true
      name: indico-sc
      provisioner: efs.csi.aws.com
      parameters:
        provisioningMode: efs-ap
        fileSystemId: ${module.efs-storage[0].efs_filesystem_id}
        directoryPerms: "700"
        gidRangeStart: "1000" # optional
        gidRangeEnd: "2000" # optional
        basePath: "/dynamic_provisioning" # optional
 EOF
  ] : []
  fsx_values = var.include_fsx == true ? [<<EOF
  aws-fsx-csi-driver:
    enabled: true
  aws-efs-csi-driver:
    enabled: ${var.local_registry_enabled} 
  storage:
    pvcSpec:
      csi:
        driver: fsx.csi.aws.com
        volumeAttributes:
          dnsname: ${module.fsx-storage[0].fsx-rwx.dns_name}
          mountname: ${module.fsx-storage[0].fsx-rwx.mount_name}
        volumeHandle: ${module.fsx-storage[0].fsx-rwx.id}
    indicoStorageClass:
      enabled: true
      name: indico-sc
      provisioner: fsx.csi.aws.com
      parameters:
        securityGroupIds: ${local.security_group_id}
        subnetId: ${module.fsx-storage[0].fsx-rwx.subnet_ids[0]}
 EOF
  ] : []
  storage_spec = var.include_fsx == true ? local.fsx_values : local.efs_values
  acm_ipa_values = var.use_acm == true ? (<<EOT
app-edge:
  alternateDomain: ""
  service:
    type: "NodePort"
    ports:
      http_port: 31755
      http_api_port: 31270
  aws-load-balancer-controller:
    enabled: true
    ingress:
      enabled: true
      annotations:
        acme.cert-manager.io/http01-edit-in-place: "true"
        cert-manager.io/cluster-issuer: zerossl      
      tls:
        - secretName: indico-ssl-cm-cert
          hosts:
            - ${local.dns_name}
      alb:
        publicSubnets: ${join(",", local.network[0].public_subnet_ids)}
        acmArn: ${aws_acm_certificate_validation.alb[0].certificate_arn}
      service:
        name: app-edge
        port: 80
      hosts:
        - host: ${local.dns_name}
          paths:
            - path: /
              pathType: Prefix
  EOT
    ) : (<<EOT
app-edge:
  alternateDomain: ""
EOT
  )
  dns_configuration_values = var.is_alternate_account_domain == "false" ? (<<EOT
clusterIssuer:
  additionalSolvers:
    - dns01:
        route53:
          region: ${var.region}
      selector:
        matchLabels:
          "acme.cert-manager.io/dns01-solver": "true"
  EOT
    ) : (<<EOT
clusterIssuer:
  additionalSolvers:
    - dns01:
        route53:
          region: ${var.region}
          role: ${var.aws_primary_dns_role_arn}
      selector:
        matchLabels:
          "acme.cert-manager.io/dns01-solver": "true"
external-dns:
  enabled: ${local.enable_external_dns}
alternate-external-dns:
  enabled: true
  logLevel: debug
  policy: sync
  txtOwnerId: "${local.dns_name}-${var.label}-${var.region}"
  domainFilters:
    - ${local.alternate_domain_root}
  extraArgs:
    - "--exclude-domains=${var.aws_account}.indico.io"
    - "--aws-assume-role=${var.aws_primary_dns_role_arn}"

  provider: aws
  aws:
    zoneType: public
    region: ${var.region}

  policy: sync
  sources:
    - ingress
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
resource "kubernetes_secret" "issuer-secret" {
  depends_on = [
    module.cluster
  ]

  metadata {
    name      = "acme-route53"
    namespace = "default"
    annotations = {
      "reflector.v1.k8s.emberstack.com/reflection-allowed"      = true
      "reflector.v1.k8s.emberstack.com/reflection-auto-enabled" = true
      "temporary.please.change/weaker-credentials-needed"       = true
    }
  }

  type = "Opaque"

  data = {
    "secret-access-key" = var.aws_secret_key
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

data "aws_route53_zone" "aws-zone" {
  name = lower("${var.aws_account}.indico.io")
}

output "ns" {
  value = data.aws_route53_zone.aws-zone.name_servers
}


resource "github_repository_file" "pre-reqs-values-yaml" {
  repository          = data.github_repository.argo-github-repo.name
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


resource "github_repository_file" "crds-values-yaml" {
  repository          = data.github_repository.argo-github-repo.name
  branch              = var.argo_branch
  file                = "${var.argo_path}/helm/crds-values.values"
  commit_message      = var.message
  overwrite_on_create = true

  lifecycle {
    ignore_changes = [
      content
    ]
  }
  content = base64decode(var.crds-values-yaml-b64)
}

data "github_repository_file" "data-crds-values" {
  depends_on = [
    github_repository_file.crds-values-yaml
  ]
  repository = data.github_repository.argo-github-repo.name
  branch     = var.argo_branch
  file       = var.argo_path == "." ? "helm/crds-values.values" : "${var.argo_path}/helm/crds-values.values"
}


data "github_repository_file" "data-pre-reqs-values" {
  depends_on = [
    github_repository_file.pre-reqs-values-yaml
  ]
  repository = data.github_repository.argo-github-repo.name
  branch     = var.argo_branch
  file       = var.argo_path == "." ? "helm/pre-reqs-values.values" : "${var.argo_path}/helm/pre-reqs-values.values"
}

resource "helm_release" "ipa-crds" {
  depends_on = [
    module.cluster,
    data.github_repository_file.data-crds-values
  ]

  verify           = false
  name             = "ipa-crds"
  create_namespace = true
  namespace        = "default"
  repository       = var.ipa_repo
  chart            = "ipa-crds"
  version          = var.ipa_crds_version
  wait             = true

  values = [
    <<EOF
  crunchy-pgo:
    enabled: true
    updateCRDs: 
      enabled: true

  
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
    ,
    <<EOT
${data.github_repository_file.data-crds-values.content}
EOT
  ]
}

resource "time_sleep" "wait_1_minutes_after_crds" {
  depends_on = [helm_release.ipa-crds]

  create_duration = "1m"
}

resource "helm_release" "ipa-pre-requisites" {
  depends_on = [
    time_sleep.wait_1_minutes_after_crds,
    module.cluster,
    module.fsx-storage,
    helm_release.ipa-crds,
    data.vault_kv_secret_v2.zerossl_data,
    data.github_repository_file.data-pre-reqs-values
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

  values = concat(local.storage_spec, [<<EOF

cluster:
  name: ${var.label}
  region: ${var.region}
  domain: indico.io
  account: ${var.aws_account}
  argoRepo: ${var.argo_repo}
  argoBranch: ${var.argo_branch}
  argoPath: ${var.argo_path}
  ipaVersion: ${var.ipa_version}
  ipaPreReqsVersion: ${var.ipa_pre_reqs_version}
  ipaCrdsVersion: ${var.ipa_crds_version}

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

${local.dns_configuration_values}

monitoring:
  enabled: true
  global:
      host: "${local.dns_name}"
    
  ingress-nginx:
    enabled: true

    rbac:
      create: true

    admissionWebhooks:
      patch:
        nodeSelector.beta.kubernetes.io/os: linux
  
    defaultBackend:
      nodeSelector.beta.kubernetes.io/os: linux
  
  authentication:
    ingressUsername: monitoring
    ingressPassword: ${random_password.monitoring-password.result}

  kube-prometheus-stack:
    prometheus:
      prometheusSpec:
        nodeSelector:
          node_group: static-workers

apiModels:
  enabled: true
  nodeSelector:
    node_group: static-workers

external-dns:
  enabled: ${local.enable_external_dns}
  logLevel: debug
  policy: sync
  txtOwnerId: "${var.label}-${var.region}"
  domainFilters:
    - ${lower(var.aws_account)}.indico.io.

  provider: aws
  aws:
    zoneType: public
    region: ${var.region}

  policy: sync
  sources:
    - service
    - ingress
aws-for-fluent-bit:
  enabled: true
  cloudWatchLogs:
    region: ${var.region}
    logGroupName: "/aws/eks/fluentbit-cloudwatch/${local.cluster_name}/logs"
    logGroupTemplate: "/aws/eks/fluentbit-cloudwatch/${local.cluster_name}/workload/$kubernetes['namespace_name']"
cluster-autoscaler:
  cluster-autoscaler:
    awsRegion: ${var.region}
    image:
      tag: "v1.20.0"
    autoDiscovery:
      clusterName: "${local.cluster_name}"
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
        storageClassName: encrypted-gp2
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
        repo1-s3-kms-key-id: "${module.kms_key.key_arn}"
        repo1-s3-role: ${module.cluster.s3_role_id}
      repos:
      - name: repo1
        s3:
          bucket: ${module.s3-storage.pgbackup_s3_bucket_name}
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
        storageClassName: encrypted-gp2
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
        repo1-s3-kms-key-id: "${module.kms_key.key_arn}"
        repo1-s3-role: ${module.cluster.s3_role_id}
      repos:
      - name: repo1
        s3:
          bucket: ${module.s3-storage.pgbackup_s3_bucket_name}
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
${data.github_repository_file.data-pre-reqs-values.content}
EOT
  ])
}

resource "time_sleep" "wait_1_minutes_after_pre_reqs" {
  depends_on = [helm_release.ipa-pre-requisites]

  create_duration = "1m"
}


data "vault_kv_secret_v2" "account-robot-credentials" {
  mount = "customer-${var.aws_account}"
  name  = "harbor-registry"
}

resource "kubernetes_namespace" "local-registry" {
  metadata {
    name = "local-registry"
  }
}

resource "kubernetes_storage_class_v1" "local-registry" {
  count = var.local_registry_enabled == true ? 1 : 0

  metadata {
    name = "local-registry"
  }

  # enabled: true
  #     parameters:
  #       provisioningMode: efs-ap
  ##       fileSystemId: ${module.efs-storage[0].efs_filesystem_id}
  #      directoryPerms: "700"
  #      gidRangeStart: "1000" # optional
  #      gidRangeEnd: "2000" # optional
  #      basePath: "/dynamic_provisioning" # optional
  storage_provisioner = "efs.csi.aws.com"
  reclaim_policy      = "Retain"
  #parameters = {
  #  fileSystemId     = module.efs-storage-local-registry[0].efs_filesystem_id
  #  provisioningMode = "efs-ap"
  #  directoryPerms   = "777"
  #  gidRangeStart    = "1000"
  #  gidRangeEnd      = "2000"
  #  basePath         = "/dynamic_provisioning"
  #}
  #mount_options = ["file_mode=0700", "dir_mode=0777", "mfsymlinks", "uid=1000", "gid=1000", "nobrl", "cache=none"]
}


resource "aws_efs_access_point" "local-registry" {
  count = var.local_registry_enabled == true ? 1 : 0

  depends_on = [module.efs-storage-local-registry[0]]

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
  file_system_id = module.efs-storage-local-registry[0].efs_filesystem_id
}


resource "kubernetes_persistent_volume_claim" "local-registry" {

  depends_on = [
    kubernetes_namespace.local-registry,
    kubernetes_persistent_volume.local-registry
  ]
  count = var.local_registry_enabled == true ? 1 : 0

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

  depends_on = [
    module.efs-storage-local-registry[0]
  ]

  count = var.local_registry_enabled == true ? 1 : 0

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
        volume_handle = "${module.efs-storage-local-registry[0].efs_filesystem_id}::${aws_efs_access_point.local-registry[0].id}"
      }
    }
  }
}


resource "random_password" "password" {
  length = 12
}

resource "random_password" "salt" {
  length = 8
}

resource "htpasswd_password" "hash" {
  password = random_password.password.result
  salt     = random_password.salt.result
}

resource "helm_release" "local-registry" {
  depends_on = [
    kubernetes_namespace.local-registry,
    time_sleep.wait_1_minutes_after_pre_reqs,
    module.cluster,
    kubernetes_persistent_volume_claim.local-registry
  ]

  count = var.local_registry_enabled == true ? 1 : 0

  verify           = false
  name             = "local-registry"
  create_namespace = false
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
      external-dns.alpha.kubernetes.io/hostname: "local-registry.${local.dns_name}"
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
    - local-registry.${local.dns_name}
    tls:
    - hosts:
      - local-registry.${local.dns_name}
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
    htpasswd: local-user:$2y$05$iIazyhgN8h.Bfkbo.Z18AOBsl.yhF9uHStDN8AcmH3p8KLdsSmjRW

localPullSecret:
  password: local-user:$2y$05$iIazyhgN8h.Bfkbo.Z18AOBsl.yhF9uHStDN8AcmH3p8KLdsSmjRW
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
registryUrl: local-registry.${local.dns_name}
restartCronjob:
  cronSchedule: 0 0 */3 * *
  disabled: false
  image: bitnami/kubectl:1.20.13
  EOF
  ]
}

output "local_registry_password" {
  value = htpasswd_password.hash.sha512
}

output "local_registry_username" {
  value = "local-user"
}


data "github_repository" "argo-github-repo" {
  full_name = "IndicoDataSolutions/${var.argo_repo}"
}

resource "github_repository_file" "smoketest-application-yaml" {
  count = var.ipa_smoketest_enabled == true ? 1 : 0

  repository          = data.github_repository.argo-github-repo.name
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
    account: ${var.aws_account}
    name: ${var.label}
  annotations:
    avp.kubernetes.io/path: tools/argo/data/ipa-deploy
    argocd.argoproj.io/sync-wave: "2"
spec:
  destination:
    server: ${module.cluster.kubernetes_host}
    namespace: default
  project: ${module.argo-registration.argo_project_name}
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
      
        - name: HELM_VALUES
          value: |
            cluster:
              name: ${var.label}
              region: ${var.region}
              account: ${var.aws_account}
            host: ${local.dns_name}
            ${indent(12, base64decode(var.ipa_smoketest_values))}    
EOT
}

resource "github_repository_file" "alb-values-yaml" {
  repository          = data.github_repository.argo-github-repo.name
  branch              = var.argo_branch
  file                = "${var.argo_path}/helm/alb.values"
  commit_message      = var.message
  overwrite_on_create = true

  lifecycle {
    ignore_changes = [
      content
    ]
  }
  depends_on = [
    module.cluster,
    aws_acm_certificate_validation.alb[0]
  ]

  content = local.acm_ipa_values
}

resource "github_repository_file" "argocd-application-yaml" {
  repository          = data.github_repository.argo-github-repo.name
  branch              = var.argo_branch
  file                = "${var.argo_path}/ipa_application.yaml"
  commit_message      = var.message
  overwrite_on_create = true

  lifecycle {
    ignore_changes = [
      content
    ]
  }
  depends_on = [
    module.cluster,
    aws_acm_certificate_validation.alb[0]
  ]

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
    server: ${module.cluster.kubernetes_host}
    namespace: default
  project: ${module.argo-registration.argo_project_name}
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
            runtime-scanner:
              enabled: ${replace(lower(var.aws_account), "indico", "") == lower(var.aws_account) ? "false" : "true"}
              authentication:
                ingressUser: monitoring
                ingressPassword: ${random_password.monitoring-password.result}
                ${indent(14, local.runtime_scanner_ingress_values)} 
            ${indent(12, local.acm_ipa_values)}         

        - name: HELM_VALUES
          value: |
            ${base64decode(var.ipa_values)}    
EOT
}


# resource "local_file" "kubeconfig" {
#   content  = module.cluster.kubectl_config
#   filename = "${path.module}/module.kubeconfig"
# }


data "vault_kv_secret_v2" "zerossl_data" {
  mount = "tools/argo"
  name  = "zerossl"
}

output "zerossl" {
  sensitive = true
  value     = data.vault_kv_secret_v2.zerossl_data.data_json
}

resource "argocd_application" "ipa" {
  depends_on = [
    # local_file.kubeconfig,
    helm_release.ipa-pre-requisites,
    time_sleep.wait_1_minutes_after_pre_reqs,
    module.argo-registration,
    kubernetes_job.snapshot-restore-job,
    github_repository_file.argocd-application-yaml,
    helm_release.monitoring
  ]

  count = var.ipa_enabled == true ? 1 : 0

  wait = true

  metadata {
    name      = lower("${var.aws_account}-${var.region}-${var.label}-deploy-ipa")
    namespace = var.argo_namespace
    labels = {
      test = "true"
    }
  }

  spec {
    project = module.argo-registration.argo_project_name

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


# Create Argo Application YAML for each user supplied application


resource "github_repository_file" "custom-application-yaml" {

  for_each = var.applications

  repository          = data.github_repository.argo-github-repo.name
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
  name: ${lower("${var.aws_account}-${var.region}-${var.label}-${each.value.name}")} 
  finalizers:
    - resources-finalizer.argocd.argoproj.io
  annotations:
     avp.kubernetes.io/path: ${each.value.vaultPath}
  labels:
    app: ${each.value.name}
    region: ${var.region}
    account: ${var.aws_account}
    name: ${var.label}
spec:
  destination:
    server: ${module.cluster.kubernetes_host}
    namespace: ${each.value.namespace}
  project: ${module.argo-registration.argo_project_name}
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

