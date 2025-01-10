locals {
  #need to get the root of alternate_domain
  the_splits            = local.dns_name != "" ? split(".", local.dns_name) : split(".", "test.domain.com")
  the_length            = length(local.the_splits)
  the_tld               = local.the_splits[local.the_length - 1]
  the_domain            = local.the_splits[local.the_length - 2]
  alternate_domain_root = join(".", [local.the_domain, local.the_tld])
  enable_external_dns   = var.use_static_ssl_certificates == false ? true : false
  storage_class         = var.on_prem_test == false ? "encrypted-gp2" : "nfs-client"
  acm_arn               = var.acm_arn == "" && var.enable_waf == true ? aws_acm_certificate_validation.alb[0].certificate_arn : var.acm_arn
  efs_values = var.include_efs == true ? [<<EOF
  storage:
    volumeSetup:
      image:
        registry: "${var.local_registry_enabled ? "local-registry.${local.dns_name}" : "${var.image_registry}"}"
    pvcSpec:
      volumeMode: Filesystem
      mountOptions: []
      csi:
        driver: efs.csi.aws.com
        volumeHandle: "${module.efs-storage[0].efs_filesystem_id}"
    indicoStorageClass:
      enabled: true
      name: indico-sc
      provisioner: efs.csi.aws.com
      parameters:
        provisioningMode: efs-ap
        fileSystemId: "${module.efs-storage[0].efs_filesystem_id}"
        directoryPerms: "700"
        gidRangeStart: "1000" # optional
        gidRangeEnd: "2000" # optional
        basePath: "/dynamic_provisioning" # optional
 EOF
  ] : []
  fsx_values = var.include_fsx == true ? [<<EOF
  storage:
    volumeSetup:
      image:
        registry: "${var.local_registry_enabled ? "local-registry.${local.dns_name}" : "${var.image_registry}"}"
    pvcSpec:
      csi:
        driver: fsx.csi.aws.com
        volumeAttributes:
          dnsname: "${module.fsx-storage[0].fsx_rwx_dns_name}"
          mountname: "${module.fsx-storage[0].fsx_rwx_mount_name}"
        volumeHandle: "${module.fsx-storage[0].fsx_rwx_id}"
    indicoStorageClass:
      enabled: true
      name: indico-sc
      provisioner: fsx.csi.aws.com
      parameters:
        securityGroupIds: ${local.security_group_id}
        subnetId: ${module.fsx-storage[0].fsx_rwx_subnet_ids[0]}
 EOF
  ] : []
  on_prem_values = var.on_prem_test == true ? [<<EOF
  storage:
    indicoStorageClass:
      enabled: false
    existingPVC:
      name: read-write
      namespace: default
    onprem:
      enabled: true
      storageClass: nfs-client
      size: 100Gi
  EOF
  ] : []
  #storage_spec = var.include_fsx == true ? local.fsx_values : local.efs_values
  storage_spec = var.on_prem_test == true ? local.on_prem_values : var.include_fsx == true ? local.fsx_values : local.efs_values

  alb_ipa_values = var.enable_waf == true ? (<<EOT
app-edge:
  image:
    registry: ${var.local_registry_enabled ? "local-registry.${local.dns_name}" : "${var.image_registry}"}/indico
  alternateDomain: ""
  cspApprovedSources:
    - ${module.s3-storage.data_s3_bucket_name}.s3.${var.region}.amazonaws.com
    - ${module.s3-storage.data_s3_bucket_name}.s3.amazonaws.com
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
  cspApprovedSources:
    - ${module.s3-storage.data_s3_bucket_name}.s3.${var.region}.amazonaws.com
    - ${module.s3-storage.data_s3_bucket_name}.s3.amazonaws.com
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
  env:
    - name: AWS_DEFAULT_REGION
      value: ${var.region}
  policy: sync
  sources:
    - service
    - ingress
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
  image:
    repository: ${var.image_registry}/registry.k8s.io/external-dns/external-dns
  logLevel: debug
  policy: sync
  txtOwnerId: "${local.dns_name}"
  domainFilters:
    - ${local.dns_zone_name}

  provider: aws
  env:
    - name: AWS_DEFAULT_REGION
      value: ${var.region}
  policy: sync
  sources:
    - service
    - ingress
alternate-external-dns:
  enabled: ${local.enable_external_dns}
  image:
    repository: ${var.image_registry}/registry.k8s.io/external-dns/external-dns
  logLevel: debug
  policy: sync
  txtOwnerId: "${local.dns_name}-${var.label}-${var.region}"
  domainFilters:
    - ${local.alternate_domain_root}
  extraArgs:
    - "--exclude-domains=${var.aws_account}.indico.io"
    - "--aws-assume-role=${var.aws_primary_dns_role_arn}"

  provider: aws
  env:
    - name: AWS_DEFAULT_REGION
      value: ${var.region}
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
    registry: local-registry.${local.dns_name}/docker.io/library

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

data "github_repository" "argo-github-repo" {
  count     = var.argo_enabled == true ? 1 : 0
  full_name = "IndicoDataSolutions/${var.argo_repo}"
}

resource "kubernetes_namespace" "indico" {
  metadata {
    name = "indico"
  }
}

# Need to make sure the pull secret is in first, so that all of our images can be pulled from harbor
resource "kubernetes_secret" "harbor-pull-secret" {
  depends_on = [
    module.cluster,
    time_sleep.wait_1_minutes_after_cluster,
    kubernetes_namespace.indico
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

# Then set up the secrets operator authentication with vault 
# (what level of permission does this require? Are we giving customers admin credentials?) 
# The auth backend they create is named <account>-<region>-<cluster-name>, so we can make 
# sure their credentials only have access to create <account>-* k8s auth methods
module "secrets-operator-setup" {
  depends_on = [
    module.cluster,
    time_sleep.wait_1_minutes_after_cluster,
    kubernetes_secret.harbor-pull-secret
  ]
  count           = var.secrets_operator_enabled == true ? 1 : 0
  source          = "./modules/common/vault-secrets-operator-setup"
  vault_address   = var.vault_address
  account         = var.aws_account
  region          = var.region
  name            = var.label
  kubernetes_host = module.cluster.kubernetes_host
}

# Once (if) the secrets operator is set up, we can deploy the common charts
locals {
  indico_crds_values = [<<EOF
migrations:
  image:
    registry: ${var.image_registry}
  vaultSecretsOperator:
    updateCRDs: ${var.secrets_operator_enabled}
  opentelemetryOperator:
    updateCRDs: ${var.monitoring_enabled}
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
      ${indent(6, yamlencode(var.default_tags))}
cert-manager:
  enabled: true
  crds:
    enabled: true
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
  extraEnv:
    - name: AWS_REGION
      value: 'aws-global'
crunchy-pgo:
  enabled: ${var.ipa_enabled || var.insights_enabled}
  updateCRDs: 
    enabled: true
  pgo: 
    controllerImages:
      cluster: ${var.image_registry}/registry.crunchydata.com/crunchydata/postgres-operator:ubi8-5.7.1-0
    relatedImages:
      postgres_17:
        image: ${var.image_registry}/registry.crunchydata.com/crunchydata/crunchy-postgres:ubi8-17.2-0
      postgres_17_gis_3.4:
        image: ${var.image_registry}/registry.crunchydata.com/crunchydata/crunchy-postgres-gis:ubi8-17.2-3.4-0
      postgres_16:
        image: ${var.image_registry}/registry.crunchydata.com/crunchydata/crunchy-postgres:ubi8-16.6-0
      postgres_16_gis_3.4:
        image: ${var.image_registry}/registry.crunchydata.com/crunchydata/crunchy-postgres-gis:ubi8-16.6-0
      postgres_16_gis_3.3:
        image: ${var.image_registry}/registry.crunchydata.com/crunchydata/crunchy-postgres-gis:ubi8-16.6-3.3-0
      postgres_15:
        image: ${var.image_registry}/registry.crunchydata.com/crunchydata/crunchy-postgres:ubi8-15.10-0
      postgres_15_gis_3.3:
        image: ${var.image_registry}/registry.crunchydata.com/crunchydata/crunchy-postgres-gis:ubi8-15.10-3.3-0
      postgres_14:
        image: ${var.image_registry}/registry.crunchydata.com/crunchydata/crunchy-postgres:ubi8-14.15-0
      postgres_14_gis_3.1:
        image: ${var.image_registry}/registry.crunchydata.com/crunchydata/crunchy-postgres-gis:ubi8-14.15-3.1-0
      postgres_14_gis_3.2:
        image: ${var.image_registry}/registry.crunchydata.com/crunchydata/crunchy-postgres-gis:ubi8-14.15-3.2-0
      postgres_14_gis_3.3:
        image: ${var.image_registry}/registry.crunchydata.com/crunchydata/crunchy-postgres-gis:ubi8-14.15-3.3-0
      postgres_13:
        image: ${var.image_registry}/registry.crunchydata.com/crunchydata/crunchy-postgres:ubi8-13.18-0
      postgres_13_gis_3.0:
        image: ${var.image_registry}/registry.crunchydata.com/crunchydata/crunchy-postgres-gis:ubi8-13.18-3.0-0
      postgres_13_gis_3.1:
        image: ${var.image_registry}/registry.crunchydata.com/crunchydata/crunchy-postgres-gis:ubi8-13.18-3.1-0
      pgadmin:
        image: ${var.image_registry}/registry.crunchydata.com/crunchydata/crunchy-pgadmin4:ubi8-4.30-32
      pgbackrest:
        image: ${var.image_registry}/registry.crunchydata.com/crunchydata/crunchy-pgbackrest:ubi8-2.53.1-1
      pgbouncer:
        image: ${var.image_registry}/registry.crunchydata.com/crunchydata/crunchy-pgbouncer:ubi8-1.23-1
      pgexporter:
        image: ${var.image_registry}/registry.crunchydata.com/crunchydata/crunchy-postgres-exporter:ubi8-0.15.0-13
      pgupgrade:
        image: ${var.image_registry}/registry.crunchydata.com/crunchydata/crunchy-upgrade:ubi8-5.7.1-0
      standalone_pgadmin:
        image: ${var.image_registry}/registry.crunchydata.com/crunchydata/crunchy-pgadmin4:ubi8-8.12-1
migrations-operator:
  enabled: ${var.ipa_enabled || var.insights_enabled}
  image:
    repository: ${var.image_registry}/indico/migrations-operator
  controllerImage:
    repository: ${var.image_registry}/indico/migrations-controller
    kubectlImage: ${var.image_registry}/indico/migrations-controller-kubectl
minio:
  enabled: ${var.insights_enabled || var.minio_enabled}
vault-secrets-operator:
  enabled: ${var.secrets_operator_enabled}
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
external-secrets:
  enabled: true
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
    enabled: true
secrets:
  clusterIssuer:
    zerossl:
      create: true
      eabEmail: devops-sa@indico.io
      eabKid: "${jsondecode(data.vault_kv_secret_v2.zerossl_data.data_json)["EAB_KID"]}"
      eabHmacKey: "${jsondecode(data.vault_kv_secret_v2.zerossl_data.data_json)["EAB_HMAC_KEY"]}"
    letsencrypt:
      create: true
    selfSigned:
      create: true
localPullSecret:
  password: "${random_password.password.result}"
  secretName: local-pull-secret
  username: local-user
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

aws-efs-csi-driver:
  enabled: ${var.include_efs ? var.include_efs : var.local_registry_enabled}
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
aws-for-fluent-bit:
  enabled: true
  image:
    repository: ${var.image_registry}/public.ecr.aws/aws-observability/aws-for-fluent-bit
  cloudWatchLogs:
    region: ${var.region}
    logGroupName: "/aws/eks/fluentbit-cloudwatch/${var.label}/logs"
    logGroupTemplate: "/aws/eks/fluentbit-cloudwatch/${var.label}/workload/$kubernetes['namespace_name']"
aws-fsx-csi-driver:
  enabled: ${var.include_fsx}
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
aws-load-balancer-controller:
  enabled: ${var.use_acm}
  aws-load-balancer-controller:
    clusterName: ${var.label}
    vpcId: ${local.network[0].indico_vpc_id}
    region: ${var.region}
cluster-autoscaler:
  enabled: true
  cluster-autoscaler:
    awsRegion: ${var.region}
    image:
      repository: ${var.image_registry}/public-gcr-k8s-proxy/autoscaling/cluster-autoscaler
      tag: "v1.20.0"
    autoDiscovery:
      clusterName: "${var.label}"
    extraArgs:
      aws-use-static-instance-list: true
${local.dns_configuration_values}
ingress-nginx:
  enabled: true
  controller:
    service:
      enableHttp: ${local.enableHttp}
      targetPorts:
        https: ${local.backend_port}
${local.lb_config}
    image:
      registry: ${var.image_registry}/registry.k8s.io
      digest: ""
    admissionWebhooks:
      patch:
        image:
          registry: ${var.image_registry}/registry.k8s.io
          digest: ""
  rbac:
    create: true

  admissionWebhooks:
    patch:
      nodeSelector.beta.kubernetes.io/os: linux

  defaultBackend:
    nodeSelector.beta.kubernetes.io/os: linux
  service:
    annotations:
      service.beta.kubernetes.io/oci-load-balancer-internal: "${local.internal_elb}"
reflector:
  image:
    repository: ${var.image_registry}/docker.io/emberstack/kubernetes-reflector
  EOF
  ]

  monitoring_values = var.monitoring_enabled ? [<<EOF
global:
  host: "${local.dns_name}"
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
  global:
    imageRegistry: ${var.image_registry}/docker.io
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
  EOF
  ] : []
}

module "indico-common" {
  depends_on = [
    module.cluster,
    time_sleep.wait_1_minutes_after_cluster,
    module.secrets-operator-setup
  ]
  source                           = "./modules/common/indico-common"
  argo_enabled                     = var.argo_enabled
  github_repo_name                 = var.argo_repo
  github_repo_branch               = var.argo_branch
  github_file_path                 = var.argo_path
  github_commit_message            = var.message
  helm_registry                    = var.ipa_repo
  namespace                        = "indico"
  indico_crds_version              = var.indico_crds_version
  crds_values_yaml_b64             = var.crds-values-yaml-b64
  indico_crds_values_overrides     = local.indico_crds_values
  indico_pre_reqs_version          = var.indico_pre_reqs_version
  indico_pre_reqs_values_overrides = local.indico_pre_reqs_values
  monitoring_enabled               = var.monitoring_enabled
  monitoring_values                = local.monitoring_values
  monitoring_version               = var.monitoring_version
}



# With the common charts are installed, we can then move on to installing intake and/or insights
locals {
  ipa_pre_reqs_values = concat(local.storage_spec, [<<EOF
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
ipaConfig:
  image:
    registry: ${var.image_registry}
apiModels:
  image:
    registry: ${var.image_registry}
secrets:
  rabbitmq:
    create: true
  general:
    create: true

celery-backend:
  redis:
    global:
      imageRegistry: ${var.image_registry}
crunchy-postgres:
  enabled: true
  postgres-data:
    enabled: true
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
        repo1-s3-role: ${module.iam.node_role_name}
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
rabbitmq:
  rabbitmq:
    image:
      registry: ${var.image_registry}
  EOF
  ])

  intake_values = <<EOF
global:
  image:
    registry: ${var.local_registry_enabled ? "local-registry.${local.dns_name}" : "${var.image_registry}"}/indico
${local.local_registry_tf_cod_values}
runtime-scanner:
  enabled: ${replace(lower(var.aws_account), "indico", "") == lower(var.aws_account) ? "false" : "true"}
  image:
    repository: ${var.local_registry_enabled ? "local-registry.${local.dns_name}" : "${var.image_registry}"}/indico-devops/runtime-scanner
  authentication:
    ingressUser: monitoring
    ingressPassword: ${random_password.monitoring-password.result}
    ${indent(4, local.runtime_scanner_ingress_values)}
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
${local.alb_ipa_values}
  EOF
}

module "intake" {
  depends_on = [
    module.indico-common
  ]
  source                            = "./modules/common/intake"
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
  account                           = var.aws_account
  region                            = var.region
  label                             = var.label
  argo_application_name             = lower("${var.aws_account}.${var.region}.${var.label}-ipa")
  vault_path                        = "tools/argo/data/ipa-deploy"
  argo_server                       = module.cluster.kubernetes_host
  argo_project_name                 = var.argo_enabled ? module.argo-registration[0].argo_project_name : ""
  intake_version                    = var.ipa_version
  k8s_version                       = var.k8s_version
  intake_values_terraform_overrides = local.intake_values
  intake_values_overrides           = var.ipa_values
}

locals {
  smoketests_values = <<EOF
  cluster:
    account: ${var.aws_account}
    region: ${var.region}
    name: ${var.label}
  host: ${local.dns_name}
  image:
    repository: ${var.local_registry_enabled ? "local-registry.${local.dns_name}" : "${var.image_registry}"}/indico/integration_tests
  ${indent(4, base64decode(var.ipa_smoketest_values))}
  EOF
}

module "intake_smoketests" {
  depends_on = [
    module.intake
  ]
  count                  = var.ipa_smoketest_enabled && var.ipa_enabled ? 1 : 0
  source                 = "./modules/common/application-deployment"
  account                = var.aws_account
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

locals {
  insights_pre_reqs_values = [<<EOF
crunchy-postgres:
  enabled: true
  postgres-data:
    enabled: true
    name: postgres-insights
    postgresVersion: 13
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
        storageClassName: ${local.storage_class}
        accessModes:
        - ReadWriteOnce
        resources:
          requests:
            storage: 200Gi
      name: pgha2
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
        repo2-path: /pgbackrest/postgres-insights/repo2
        repo2-retention-full: '5'
        repo2-s3-key-type: auto
        repo2-s3-kms-key-id: "${module.kms_key.key_arn}"
        repo2-s3-role: ${module.iam.node_role_name}
      repos:
      - name: repo2
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
rabbitmq:
  rabbitmq:
    image:
      registry: ${var.image_registry}
  EOF
  ])

  intake_values = <<EOF
global:
  image:
    registry: ${var.local_registry_enabled ? "local-registry.${local.dns_name}" : "${var.image_registry}"}/indico
${local.local_registry_tf_cod_values}
runtime-scanner:
  enabled: ${replace(lower(var.aws_account), "indico", "") == lower(var.aws_account) ? "false" : "true"}
  image:
    repository: ${var.local_registry_enabled ? "local-registry.${local.dns_name}" : "${var.image_registry}"}/indico-devops/runtime-scanner
  authentication:
    ingressUser: monitoring
    ingressPassword: ${random_password.monitoring-password.result}
    ${indent(6, local.runtime_scanner_ingress_values)}
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
${local.alb_ipa_values}
  EOF
}

module "intake" {
  depends_on = [
    module.indico-common
  ]
  source                            = "./modules/common/intake"
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
  account                           = var.aws_account
  region                            = var.region
  label                             = var.label
  argo_application_name             = lower("${var.aws_account}.${var.region}.${var.label}-ipa")
  vault_path                        = ""
  argo_server                       = module.cluster.kubernetes_host
  argo_project_name                 = module.argo-registration[0].argo_project_name
  intake_version                    = var.ipa_version
  k8s_version                       = var.k8s_version
  intake_values_terraform_overrides = local.intake_values
  intake_values_overrides           = var.ipa_values
}

locals {
  smoketests_values = <<EOF
  cluster:
    cloudProvider: aws
    account: ${var.aws_account}
    region: ${var.region}
    name: ${var.label}
  host: ${local.dns_name}
  image:
    repository: ${var.local_registry_enabled ? "local-registry.${local.dns_name}" : "${var.image_registry}"}/indico/integration_tests
  ${indent(4, base64decode(var.ipa_smoketest_values))}
  EOF
}

module "intake_smoketests" {
  depends_on = [
    module.intake
  ]
  count                  = var.ipa_smoketest_enabled && var.ipa_enabled ? 1 : 0
  source                 = "./modules/common/application-deployment"
  account                = var.aws_account
  region                 = var.region
  label                  = var.label
  namespace              = "default"
  argo_enabled           = var.argo_enabled
  github_repo_name       = var.argo_repo
  github_repo_branch     = var.argo_branch
  github_file_path       = "${var.argo_path}/ipa_smoketest.yaml"
  github_commit_message  = var.message
  argo_application_name  = local.argo_smoketest_app_name
  argo_vault_plugin_path = ""
  argo_server            = module.cluster.kubernetes_host
  argo_project_name      = var.argo_enabled ? module.argo-registration[0].argo_project_name : ""
  chart_name             = "cod-smoketests"
  chart_repo             = var.ipa_smoketest_repo
  chart_version          = var.ipa_smoketest_version
  k8s_version            = var.k8s_version
  release_name           = "run"
  terraform_helm_values  = ""
  helm_values            = indent(12, trimspace(local.smoketests_values))
}

locals {
  insights_pre_reqs_values = [<<EOF
crunchy-postgres:
  enabled: true
  postgres-data:
    enabled: true
    name: postgres
    postgresVersion: 13
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
        repo1-s3-role: ${module.iam.node_role_name}
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
      monitoring: true
      users:
        - name: indico
          options: "SUPERUSER"
          databases:
            - aqueduct
            - ask_my_collection
            - lagoon
      patroni:
        dynamicConfiguration:
          postgresql:
            listen: "*"
            pg_hba:
              - host all all 0.0.0.0/0 password
            parameters:
              max_worker_processes: 90
              max_parallel_workers_per_gather: 20
              force_parallel_mode: 0
              work_mem: 131072
              wal_level: logical
              max_stack_depth: 6144
              max_connections: 1000
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
        repo1-s3-role: ${module.iam.node_role_name}
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
ingress:
  useStaticCertificate: false
  secretName: indico-ssl-static-cert
  tls.crt: #base64 encoded value of certificate chain
  tls.key: #base64 encoded value of certificate key
minio:
  topology:
    volumeSize: 128Gi
  storage:
    accessKey: <path:tools/argo/data/indico-dev/ins-dev/storage#access_key_id>
    secretKey: <path:tools/argo/data/indico-dev/ins-dev/storage#secret_access_key>
weaviate:
  cronjob:
    services:
      weaviate-backup:
        enabled: true
  backupStorageConfig:
    accessKey: <path:tools/argo/data/indico-dev/ins-dev/storage#access_key_id>
    secretKey: <path:tools/argo/data/indico-dev/ins-dev/storage#secret_access_key>
    url: http://minio-tenant-hl.insights.svc.cluster.local:9000
  weaviate:
    env:
      GOMEMLIMIT: "31GiB" # 1 less than the hard limit on the used nodes 
    backups:
      s3:
        enabled: true
        envconfig:
          BACKUP_S3_ENDPOINT: minio-tenant-hl.insights.svc.cluster.local:9000
        secrets:
          AWS_ACCESS_KEY_ID: <path:tools/argo/data/indico-dev/ins-dev/storage#access_key_id>
          AWS_SECRET_ACCESS_KEY: <path:tools/argo/data/indico-dev/ins-dev/storage#secret_access_key>
  EOF
  ]

  insights_values = <<EOF
global:
  host: ${var.label}.${var.region}.indico-dev.indico.io
  features:
    askMyDocument: true
  intake:
    host: dev-ci.us-east-2.indico-dev.indico.io
    apiToken: <path:tools/argo/data/indico-dev/ins-dev/intake#api_token>
    tokenSecret: <path:tools/argo/data/indico-dev/ins-dev/intake#noct_token_secret>
    cookieSecret: <path:tools/argo/data/indico-dev/ins-dev/intake#noct_cookie_secret>
insights-edge:
  additionalAllowedOrigins:
    - https://local.indico.io:1234
server:
  services:
    lagoon:
      env:
        FIELD_AUTOCONFIRM_CONFIDENCE: 0.8
        FIELD_CONFIG_PATH: "fields_config.yaml"
cronjob:
  enabled: false
ask-my-docs:
  llmConfig:
    llm: indico-azure-instance
    azure:
      apiBase: https://indico-openai.openai.azure.com/
      deployment: indico-gpt-4
      apiKey: <path:tools/argo/data/RandD/azureOpenAiKey#apiKey>
  EOF
}

module "insights" {
  depends_on = [
    module.indico-common
  ]
  source                              = "./modules/common/insights"
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
  account                             = var.aws_account
  region                              = var.region
  label                               = var.label
  argo_application_name               = lower("${var.aws_account}.${var.region}.${var.label}-ipa")
  vault_path                          = ""
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

  source                 = "./modules/common/application-deployment"
  account                = var.aws_account
  region                 = var.region
  label                  = var.label
  namespace              = each.value.namespace
  argo_enabled           = var.argo_enabled
  github_repo_name       = var.argo_repo
  github_repo_branch     = var.argo_branch
  github_file_path       = "${var.argo_path}/${each.value.name}_application.yaml"
  github_commit_message  = var.message
  argo_application_name  = lower("${var.aws_account}-${var.region}-${var.label}-${each.value.name}")
  argo_vault_plugin_path = each.value.vaultPath
  argo_server            = module.cluster.kubernetes_host
  argo_project_name      = var.argo_enabled ? module.argo-registration[0].argo_project_name : ""
  chart_name             = each.value.chart
  chart_repo             = each.value.repo
  chart_version          = each.value.version
  k8s_version            = var.k8s_version
  release_name           = each.value.name
  terraform_helm_values  = ""
  helm_values            = base64decode(each.value.values)
}


resource "argocd_application" "ipa" {
  depends_on = [
    # local_file.kubeconfig,
    module.intake,
    module.argo-registration,
    kubernetes_job.snapshot-restore-job,
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

output "harbor-api-token" {
  sensitive = true
  value     = var.argo_enabled == true ? jsondecode(data.vault_kv_secret_v2.harbor-api-token[0].data_json)["bearer_token"] : ""
}

output "smoketest_chart_version" {
  value = "${path.module}/validate_chart.sh terraform-smoketests 0.1.1-${data.external.git_information.result.branch}-${substr(data.external.git_information.result.sha, 0, 8)}"
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
    module.indico-common
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

data "vault_kv_secret_v2" "zerossl_data" {
  mount = var.vault_mount_path
  name  = "zerossl"
}

output "zerossl" {
  sensitive = true
  value     = data.vault_kv_secret_v2.zerossl_data.data_json
}
