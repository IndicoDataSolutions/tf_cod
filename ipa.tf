locals {
  #need to get the root of alternate_domain
  the_splits            = local.dns_name != "" ? split(".", local.dns_name) : split(".", "test.domain.com")
  the_length            = length(local.the_splits)
  the_tld               = local.the_splits[local.the_length - 1]
  the_domain            = local.the_splits[local.the_length - 2]
  alternate_domain_root = join(".", [local.the_domain, local.the_tld])

  storage_class = var.on_prem_test == false ? "encrypted-gp2" : "nfs-client"

  enable_external_dns = var.use_static_ssl_certificates == false ? true : false
  acm_arn             = var.acm_arn == "" && var.enable_waf == true ? aws_acm_certificate_validation.alb[0].certificate_arn : var.acm_arn
  efs_values = var.include_efs == true ? [<<EOF
  aws-fsx-csi-driver:
    enabled: false
  aws-efs-csi-driver:
    enabled: true
  storage:
    volumeSetup:
      image:
        registry: "${var.local_registry_enabled ? "local-registry.${local.dns_name}" : "${var.image_registry}"}"
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
    volumeSetup:
      image:
        registry: "${var.local_registry_enabled ? "local-registry.${local.dns_name}" : "${var.image_registry}"}"
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
  alb_ipa_values = var.enable_waf == true ? (<<EOT
app-edge:
  image:
    registry: ${var.local_registry_enabled ? "local-registry.${local.dns_name}" : "${var.image_registry}"}/indico
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
            - ${local.dns_name}
      alb:
        publicSubnets: ${join(",", local.network[0].public_subnet_ids)}
        wafArn: ${aws_wafv2_web_acl.wafv2-acl[0].arn}
        acmArn: ${local.acm_arn}
      service:
        name: app-edge
        port: 8080
      hosts:
        - host: ${local.dns_name}
          paths:
            - path: /
              pathType: Prefix
  EOT
    ) : (<<EOT
app-edge:
  alternateDomain: ""
  image:
    registry: ${var.local_registry_enabled ? "local-registry.${local.dns_name}" : "${var.image_registry}"}/indico
    ingress:
      useStaticCertificate: ${var.use_static_ssl_certificates}
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

  policy: sync
  sources:
    - ingress
EOT
  )
  local_registry_tf_cod_values = var.local_registry_enabled == true ? (<<EOT
global:
  imagePullSecrets: 
    - name: local-pull-secret
    - name: harbor-pull-secret
  image:
    registry: local-registry.${local.dns_name}/indico

app-edge:
  image:
    registry: local-registry.${local.dns_name}/indico
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
  dns01RecursiveNameserversOnly = var.network_allow_public == true ? false : true
  dns01RecursiveNameservers     = var.network_allow_public == true ? "" : "kube-dns.kube-system.svc.cluster.local:53"
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

output "ns" {
  value = var.use_static_ssl_certificates ? ["no-hosted-zone"] : data.aws_route53_zone.primary[0].name_servers
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


resource "github_repository_file" "crds-values-yaml" {
  count               = var.argo_enabled == true ? 1 : 0
  repository          = data.github_repository.argo-github-repo[0].name
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
  count = var.argo_enabled == true ? 1 : 0
  depends_on = [
    github_repository_file.crds-values-yaml
  ]
  repository = data.github_repository.argo-github-repo[0].name
  branch     = var.argo_branch
  file       = var.argo_path == "." ? "helm/crds-values.values" : "${var.argo_path}/helm/crds-values.values"
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

module "secrets-operator-setup" {
  depends_on = [
    module.cluster
  ]
  count           = var.secrets_operator_enabled == true ? 1 : 0
  source          = "./modules/common/vault-secrets-operator-setup"
  vault_address   = var.vault_address
  account         = var.aws_account
  region          = var.region
  name            = var.label
  kubernetes_host = module.cluster.kubernetes_host
}


resource "helm_release" "ipa-vso" {
  count = var.thanos_enabled == true ? 1 : 0
  depends_on = [
    module.cluster,
    data.github_repository_file.data-crds-values,
    module.secrets-operator-setup
  ]

  verify           = false
  name             = "ipa-vso"
  create_namespace = true
  namespace        = "default"
  repository       = "https://helm.releases.hashicorp.com"
  chart            = "vault-secrets-operator"
  version          = var.vault_secrets_operator_version
  wait             = true
  values = [
    <<EOF
  controller: 
    imagePullSecrets:
      - name: harbor-pull-secret
    kubeRbacProxy:
      image:
        repository: ${var.image_registry}/gcr.io/kubebuilder/kube-rbac-proxy
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
EOF
  ]
}

resource "helm_release" "external-secrets" {
  depends_on = [
    module.cluster,
    data.github_repository_file.data-crds-values,
    module.secrets-operator-setup
  ]


  verify           = false
  name             = "external-secrets"
  create_namespace = true
  namespace        = "default"
  repository       = "https://charts.external-secrets.io/"
  chart            = "external-secrets"
  version          = var.external_secrets_version
  wait             = true

  values = [<<EOF
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

}


resource "helm_release" "ipa-crds" {
  depends_on = [
    module.cluster,
    data.github_repository_file.data-crds-values,
    module.secrets-operator-setup
  ]

  verify           = false
  name             = "ipa-crds"
  create_namespace = true
  namespace        = "default"
  repository       = var.ipa_repo
  chart            = "ipa-crds"
  version          = var.ipa_crds_version
  wait             = true
  timeout          = "1800" # 30 minutes

  values = [
    <<EOF
  crunchy-pgo:
    enabled: true
    updateCRDs: 
      enabled: true
    pgo: 
      controllerImages:
        cluster: ${var.image_registry}/registry.crunchydata.com/crunchydata/postgres-operator:ubi8-5.5.0-2
      relatedImages:
        postgres_16:
          image: ${var.image_registry}/registry.crunchydata.com/crunchydata/crunchy-postgres:ubi8-16.1-2
        postgres_16_gis_3.4:
          image: ${var.image_registry}/registry.crunchydata.com/crunchydata/crunchy-postgres-gis:ubi8-16.1-3.4-2
        postgres_16_gis_3.3:
          image: ${var.image_registry}/registry.crunchydata.com/crunchydata/crunchy-postgres-gis:ubi8-16.1-3.3-2
        postgres_15:
          image: ${var.image_registry}/registry.crunchydata.com/crunchydata/crunchy-postgres:ubi8-15.5-2
        postgres_15_gis_3.3:
          image: ${var.image_registry}/registry.crunchydata.com/crunchydata/crunchy-postgres-gis:ubi8-15.5-3.3-2
        postgres_14:
          image: ${var.image_registry}/registry.crunchydata.com/crunchydata/crunchy-postgres:ubi8-14.10-2
        postgres_14_gis_3.1:
          image: ${var.image_registry}/registry.crunchydata.com/crunchydata/crunchy-postgres-gis:ubi8-14.10-3.1-2
        postgres_14_gis_3.2:
          image: ${var.image_registry}/registry.crunchydata.com/crunchydata/crunchy-postgres-gis:ubi8-14.10-3.2-2
        postgres_14_gis_3.3:
          image: ${var.image_registry}/registry.crunchydata.com/crunchydata/crunchy-postgres-gis:ubi8-14.10-3.3-2
        postgres_13:
          image: ${var.image_registry}/registry.crunchydata.com/crunchydata/crunchy-postgres:ubi8-13.13-2
        postgres_13_gis_3.0:
          image: ${var.image_registry}/registry.crunchydata.com/crunchydata/crunchy-postgres-gis:ubi8-13.13-3.0-2
        postgres_13_gis_3.1:
          image: ${var.image_registry}/registry.crunchydata.com/crunchydata/crunchy-postgres-gis:ubi8-13.13-3.1-2
        pgadmin:
          image: ${var.image_registry}/registry.crunchydata.com/crunchydata/crunchy-pgadmin4:ubi8-4.30-21
        pgbackrest:
          image: ${var.image_registry}/registry.crunchydata.com/crunchydata/crunchy-pgbackrest:ubi8-2.47-4
        pgbouncer:
          image: ${var.image_registry}/registry.crunchydata.com/crunchydata/crunchy-pgbouncer:ubi8-1.21-2
        pgexporter:
          image: ${var.image_registry}/registry.crunchydata.com/crunchydata/crunchy-postgres-exporter:ubi8-0.15.0-0
        pgupgrade:
          image: ${var.image_registry}/registry.crunchydata.com/crunchydata/crunchy-upgrade:ubi8-5.5.0-2
        standalone_pgadmin:
          image: ${var.image_registry}/registry.crunchydata.com/crunchydata/crunchy-pgadmin4:ubi8-7.8-2
  migrations-operator:
    image:
      repository: ${var.image_registry}/indico/migrations-operator
      tag: "3.0.13"
    controllerImage:
      repository: ${var.image_registry}/indico/migrations-controller
      kubectlImage: ${var.image_registry}/indico/migrations-controller-kubectl
      tag: "3.0.12"
  aws-ebs-csi-driver:
    image:
      repository: ${var.image_registry}/public.ecr.aws/ebs-csi-driver/aws-ebs-csi-driver
    sidecars:
      provisioner:
        image:
          repository: ${var.image_registry}/public.ecr.aws/eks-distro/kubernetes-csi/external-provisioner
      attacher:
        image:
          repository: ${var.image_registry}/public.ecr.aws/eks-distro/kubernetes-csi/external-attacher
      snapshotter:
        image:
          repository: ${var.image_registry}/public.ecr.aws/eks-distro/kubernetes-csi/external-snapshotter/csi-snapshotter
      livenessProbe:
        image:
          repository: ${var.image_registry}/public.ecr.aws/eks-distro/kubernetes-csi/livenessprobe
      resizer:
        image:
          repository: ${var.image_registry}/public.ecr.aws/eks-distro/kubernetes-csi/external-resizer
      nodeDriverRegistrar:
        image:
          repository: ${var.image_registry}/public.ecr.aws/eks-distro/kubernetes-csi/node-driver-registrar
    controller:
      extraVolumeTags:
        ${indent(8, yamlencode(var.default_tags))}

  cert-manager:
    dns01RecursiveNameservers: ${local.dns01RecursiveNameservers}
    dns01RecursiveNameserversOnly: ${local.dns01RecursiveNameserversOnly}
    nodeSelector:
      kubernetes.io/os: linux
    webhook:
      nodeSelector:
        kubernetes.io/os: linux
    cainjector:
      nodeSelector:
        kubernetes.io/os: linux
    image:
      repository: ${var.image_registry}/quay.io/jetstack/cert-manager-controller
    webhook:
      image:
        repository: ${var.image_registry}/quay.io/jetstack/cert-manager-webhook
    cainjector:
      image:
        repository: ${var.image_registry}/quay.io/jetstack/cert-manager-cainjector
    acmesolver:
      image:
        repository: ${var.image_registry}/quay.io/jetstack/cert-manager-acmesolver
    startupapicheck:
      image:
        repository: ${var.image_registry}/quay.io/jetstack/cert-manager-startupapicheck
    enabled: true
    installCRDs: true
EOF
    ,
    <<EOT
${var.argo_enabled == true ? data.github_repository_file.data-crds-values[0].content : ""}
EOT
  ]
}


resource "time_sleep" "wait_1_minutes_after_crds" {
  depends_on = [helm_release.ipa-crds]

  create_duration = "1m"
}

resource "kubectl_manifest" "thanos-storage-secret" {
  count      = var.thanos_enabled ? 1 : 0
  depends_on = [helm_release.ipa-crds, module.secrets-operator-setup]
  yaml_body  = <<YAML
    apiVersion: "secrets.hashicorp.com/v1beta1"
    kind: "VaultStaticSecret"
    metadata:
      name:  vault-thanos-storage
      namespace: default
    spec:
      type: "kv-v2"
      namespace: default
      mount: customer-Indico-Devops
      path: thanos-storage
      refreshAfter: 60s
      rolloutRestartTargets:
        - name: prometheus-monitoring-kube-prometheus-prometheus
          kind: StatefulSet
      destination:
        annotations:
          reflector.v1.k8s.emberstack.com/reflection-allowed: "true"
          reflector.v1.k8s.emberstack.com/reflection-auto-enabled: "true"
        create: true
        name: thanos-storage
      vaultAuthRef: default
  YAML
}

resource "helm_release" "ipa-pre-requisites" {
  depends_on = [
    time_sleep.wait_1_minutes_after_crds,
    module.cluster,
    module.fsx-storage,
    helm_release.ipa-crds,
    data.vault_kv_secret_v2.zerossl_data,
    data.github_repository_file.data-pre-reqs-values,
    null_resource.update_storage_class
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
global:
  image:
    registry: ${var.image_registry}
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
alternate-external-dns:
  image:
    repository: ${var.image_registry}/registry.k8s.io/external-dns/external-dns
external-dns:
  enabled: ${local.enable_external_dns}
  image:
    repository: ${var.image_registry}/registry.k8s.io/external-dns/external-dns
  logLevel: debug
  policy: sync
  txtOwnerId: "${local.dns_name}"
  domainFilters:
    - ${local.dns_zone_name}

  provider: aws
  policy: sync
  sources:
    - service
    - ingress
aws-for-fluent-bit:
  enabled: true
  image:
    repository: ${var.image_registry}/public.ecr.aws/aws-observability/aws-for-fluent-bit
  cloudWatchLogs:
    region: ${var.region}
    logGroupName: "/aws/eks/fluentbit-cloudwatch/${var.label}/logs"
    logGroupTemplate: "/aws/eks/fluentbit-cloudwatch/${var.label}/workload/$kubernetes['namespace_name']"
ipaConfig:
  image:
    registry: ${var.image_registry}
rabbitmq:
  rabbitmq:
    image:
      registry: ${var.image_registry}
cluster-autoscaler:
  cluster-autoscaler:
    awsRegion: ${var.region}
    image:
      repository: ${var.image_registry}/public-gcr-k8s-proxy/autoscaling/cluster-autoscaler
      tag: "v1.20.0"
    autoDiscovery:
      clusterName: "${var.label}"
    extraArgs:
      aws-use-static-instance-list: true
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
reflector:
  image:
    repository: ${var.image_registry}/docker.io/emberstack/kubernetes-reflector
apiModels:
  image:
    registry: ${var.image_registry}
migrationsArtifactsInstall:
  image:
    registry: ${var.image_registry}
aws-load-balancer-controller:
  enabled: ${var.use_acm}
  aws-load-balancer-controller:
    clusterName: ${var.label}
    vpcId: ${local.network[0].indico_vpc_id}
    region: ${var.region}
aws-fsx-csi-driver:
  image:  
    repository: ${var.image_registry}/public.ecr.aws/fsx-csi-driver/aws-fsx-csi-driver
    pullPolicy: IfNotPresent
  imagePullSecrets:
    - harbor-pull-secret
  sidecars:
    livenessProbe:
      image:
        repository: ${var.image_registry}/public.ecr.aws/eks-distro/kubernetes-csi/livenessprobe
    nodeDriverRegistrar:
      image:
        repository: ${var.image_registry}/public.ecr.aws/eks-distro/kubernetes-csi/node-driver-registrar
    provisioner:
      image:
        repository: ${var.image_registry}/public.ecr.aws/eks-distro/kubernetes-csi/external-provisioner
    resizer:
      image:
        repository: ${var.image_registry}/public.ecr.aws/eks-distro/kubernetes-csi/external-resizer
aws-efs-csi-driver:
  image:
    repository: ${var.image_registry}/docker.io/amazon/aws-efs-csi-driver
  sidecars:
    livenessProbe:
      image:
        repository: ${var.image_registry}/public.ecr.aws/eks-distro/kubernetes-csi/livenessprobe
    nodeDriverRegistrar:
      image:
        repository: ${var.image_registry}/public.ecr.aws/eks-distro/kubernetes-csi/node-driver-registrar
    csiProvisioner:
      image:
        repository: ${var.image_registry}/public.ecr.aws/eks-distro/kubernetes-csi/external-provisioner
metrics-server:
  global:
    imageRegistry: ${var.image_registry}/docker.io
celery-backend:
  redis:
    global:
      imageRegistry: ${var.image_registry}
opentelemetry-operator:
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
EOF
    ,
    <<EOT
${var.argo_enabled == true ? data.github_repository_file.data-pre-reqs-values[0].content : ""}
EOT
  ])
}


#resource "null_resource" "tfc" {
#  triggers = {
#    always_run = "${timestamp()}"
#  }
#
#  provisioner "local-exec" {
#    command = "env|sort"
#  }
#}

data "external" "git_information" {
  program = ["sh", "${path.module}/get_sha.sh"]
}

output "git_sha" {
  value = data.external.git_information.result.sha
}


output "git_branch" {
  value = data.external.git_information.result.branch
}

/*
resource "null_resource" "sleep-5-minutes-wait-for-charts-smoketest-build" {
  depends_on = [
    time_sleep.wait_1_minutes_after_pre_reqs
  ]

  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    command = "sleep 300"
  }
}
*/

resource "null_resource" "wait-for-tf-cod-chart-build" {
  count = var.argo_enabled == true ? 1 : 0

  depends_on = [
    time_sleep.wait_1_minutes_after_pre_reqs
  ]

  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    environment = {
      HARBOR_API_TOKEN = jsondecode(data.vault_kv_secret_v2.harbor-api-token[0].data_json)["bearer_token"]
    }
    command = "${path.module}/validate_chart.sh terraform-smoketests 0.1.0-${data.external.git_information.result.branch}-${substr(data.external.git_information.result.sha, 0, 8)}"
  }
}


output "harbor-api-token" {
  sensitive = true
  value     = var.argo_enabled == true ? jsondecode(data.vault_kv_secret_v2.harbor-api-token[0].data_json)["bearer_token"] : ""
}

output "smoketest_chart_version" {
  value = "${path.module}/validate_chart.sh terraform-smoketests 0.1.0-${data.external.git_information.result.branch}-${substr(data.external.git_information.result.sha, 0, 8)}"
}

resource "helm_release" "terraform-smoketests" {
  count = var.terraform_smoketests_enabled == true ? 1 : 0

  depends_on = [
    null_resource.wait-for-tf-cod-chart-build,
    #null_resource.sleep-5-minutes-wait-for-charts-smoketest-build,
    kubernetes_config_map.terraform-variables,
    helm_release.monitoring
  ]

  verify           = false
  name             = "terraform-smoketests-${substr(data.external.git_information.result.sha, 0, 8)}"
  namespace        = "default"
  repository       = var.ipa_repo
  chart            = "terraform-smoketests"
  version          = "0.1.0-${data.external.git_information.result.branch}-${substr(data.external.git_information.result.sha, 0, 8)}"
  wait             = true
  wait_for_jobs    = true
  timeout          = "300" # 5 minutes
  disable_webhooks = false
  values = [<<EOF
  cluster:
    cloudProvider: aws
    account: ${var.aws_account}
    region: ${var.region}
    name: ${var.label}
  image:
    repository: ${var.image_registry}/indico/terraform-smoketests
    tag: "${substr(data.external.git_information.result.sha, 0, 8)}"
  EOF
  ]
}

resource "time_sleep" "wait_1_minutes_after_pre_reqs" {
  depends_on = [helm_release.ipa-pre-requisites]

  create_duration = "1m"
}

data "vault_kv_secret_v2" "account-robot-credentials" {
  count = var.local_registry_enabled == true ? 1 : 0
  mount = "customer-${var.aws_account}"
  name  = "harbor-registry"
}


data "vault_kv_secret_v2" "harbor-api-token" {
  count = var.argo_enabled == true ? 1 : 0
  mount = "tools/argo"
  name  = "harbor-api"
}

resource "kubernetes_namespace" "local-registry" {
  count = var.local_registry_enabled == true ? 1 : 0
  metadata {
    name = "local-registry"
  }
}

resource "kubernetes_storage_class_v1" "local-registry" {
  count = var.local_registry_enabled == true ? 1 : 0

  metadata {
    name = "local-registry"
  }

  storage_provisioner = "efs.csi.aws.com"
  reclaim_policy      = "Retain"
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
  image:
    repository: ${var.image_registry}/docker.io/library/registry
    imagePullSecrets:
      - name: harbor-pull-secret
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
    remoteurl: https://${var.image_registry}
    secretRef: remote-access
  replicaCount: 3
  
  secrets:
    htpasswd: local-user:${htpasswd_password.hash.bcrypt}

localPullSecret:
  password: ${random_password.password.result}
  secretName: local-pull-secret
  username: local-user

metrics-server:
  apiService:
    create: true
  enabled: false

proxyRegistryAccess:
  proxyPassword: ${var.local_registry_enabled == true ? jsondecode(data.vault_kv_secret_v2.account-robot-credentials[0].data_json)["harbor_password"] : ""}
  proxyPullSecretName: remote-access
  proxyUrl: https://${var.image_registry}
  proxyUsername: ${var.local_registry_enabled == true ? jsondecode(data.vault_kv_secret_v2.account-robot-credentials[0].data_json)["harbor_username"] : ""}
  
registryUrl: local-registry.${local.dns_name}
restartCronjob:
  cronSchedule: 0 0 */3 * *
  disabled: false
  image: bitnami/kubectl:1.20.13
  EOF
  ]
}

output "local_registry_password" {
  value = htpasswd_password.hash.bcrypt
}

output "local_registry_username" {
  value = "local-user"
}


data "github_repository" "argo-github-repo" {
  count     = var.argo_enabled == true ? 1 : 0
  full_name = "IndicoDataSolutions/${var.argo_repo}"
}

resource "github_repository_file" "smoketest-application-yaml" {
  count = var.ipa_smoketest_enabled == true && var.argo_enabled == true ? 1 : 0

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
    account: ${var.aws_account}
    name: ${var.label}
  annotations:
    avp.kubernetes.io/path: tools/argo/data/ipa-deploy
    argocd.argoproj.io/sync-wave: "2"
spec:
  destination:
    server: ${module.cluster.kubernetes_host}
    namespace: default
  project: ${module.argo-registration[0].argo_project_name}
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
            image:
              repository: ${var.local_registry_enabled ? "local-registry.${local.dns_name}" : "${var.image_registry}"}/indico/integration_tests
            ${indent(12, base64decode(var.ipa_smoketest_values))}    
EOT
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
  depends_on = [
    module.cluster,
    aws_acm_certificate_validation.alb[0]
  ]

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
  depends_on = [
    module.cluster,
    aws_wafv2_web_acl.wafv2-acl[0]
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
  project: ${module.argo-registration[0].argo_project_name}
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
                registry: ${var.local_registry_enabled ? "local-registry.${local.dns_name}" : "${var.image_registry}"}/indico
            ${indent(12, local.local_registry_tf_cod_values)}
            runtime-scanner:
              enabled: ${replace(lower(var.aws_account), "indico", "") == lower(var.aws_account) ? "false" : "true"}
              image:
                repository: ${var.local_registry_enabled ? "local-registry.${local.dns_name}" : "${var.image_registry}"}/indico-devops/runtime-scanner
              authentication:
                ingressUser: monitoring
                ingressPassword: ${random_password.monitoring-password.result}
                ${indent(14, local.runtime_scanner_ingress_values)}
            celery-flower:
              image:
              
                repository: ${var.local_registry_enabled ? "local-registry.${local.dns_name}" : "${var.image_registry}"}/indico/flower
            aws-node-termination:
              aws-node-termination-handler:
                image:
                  repository: ${var.local_registry_enabled ? "local-registry.${local.dns_name}" : "${var.image_registry}"}/indico/aws-node-termination-handler
            nvidia-device-plugin:
              nvidia-device-plugin:
                image:
                  repository: ${var.local_registry_enabled ? "local-registry.${local.dns_name}" : "${var.image_registry}"}/public-nvcr-proxy/nvidia/k8s-device-plugin
            reloader:
              reloader:
                reloader:
                  deployment:
                    image:
                      name: ${var.local_registry_enabled ? "local-registry.${local.dns_name}" : "${var.image_registry}"}/dockerhub-proxy/stakater/reloader
            kafka-strimzi:
              strimzi-kafka-operator: 
                defaultImageRegistry: ${var.local_registry_enabled ? "local-registry.${local.dns_name}" : "${var.image_registry}"}/strimzi-proxy
              kafkacat:
                image:
                  registry: ${var.local_registry_enabled ? "local-registry.${local.dns_name}" : "${var.image_registry}"}/dockerhub-proxy/confluentinc
              schemaRegistry:
                image:
                  registry: ${var.local_registry_enabled ? "local-registry.${local.dns_name}" : "${var.image_registry}"}/dockerhub-proxy/confluentinc
              kafkaConnect:
                image:
                  registry: ${var.local_registry_enabled ? "local-registry.${local.dns_name}" : "${var.image_registry}"}/indico
            ${indent(12, local.alb_ipa_values)}         

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
  mount = var.vault_mount_path
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
  project: ${module.argo-registration[0].argo_project_name}
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

