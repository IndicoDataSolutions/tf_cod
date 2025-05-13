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
        volumeHandle: "${local.environment_efs_filesystem_id}"
    indicoStorageClass:
      name: ${var.indico_storage_class_name}
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
          dnsname: "${local.environment_fsx_rwx_dns_name}"
          mountname: "${local.environment_fsx_rwx_mount_name}"
        volumeHandle: "${local.environment_fsx_rwx_id}"
    indicoStorageClass:
      name: ${var.indico_storage_class_name}
 EOF
  ] : []
  on_prem_values = var.on_prem_test == true ? [<<EOF
  storage:
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
  applicationCluster:
    enabled: ${var.enable_data_application_cluster_separation ? var.load_environment == "" ? "false" : "true" : "true"}
  backendServiceName: ${var.enable_data_application_cluster_separation ? "app-edge-application-cluster" : "app-edge"}
  image:
    registry: ${var.local_registry_enabled ? "local-registry.${local.dns_name}" : "${var.image_registry}"}/indico
  alternateDomain: ""
  cspApprovedSources:
    - ${local.environment_data_s3_bucket_name}.s3.${var.region}.amazonaws.com
    - ${local.environment_data_s3_bucket_name}.s3.amazonaws.com
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
        publicSubnets: ${join(",", local.environment_public_subnet_ids)}
        wafArn: ${aws_wafv2_web_acl.wafv2-acl[0].arn}
        acmArn: ${local.acm_arn}
      service:
        name: ${var.enable_data_application_cluster_separation ? "app-edge-application-cluster" : "app-edge"}
        port: 8080
      hosts:
        - host: ${local.dns_name}
          paths:
            - path: /
              pathType: Prefix
  EOT
    ) : (<<EOT
app-edge:
  applicationCluster:
    enabled: ${var.enable_data_application_cluster_separation ? var.load_environment == "" ? "false" : "true" : "true"}
  backendServiceName: ${var.enable_data_application_cluster_separation ? "app-edge-application-cluster" : "app-edge"}
  cspApprovedSources:
    - ${local.environment_data_s3_bucket_name}.s3.${var.region}.amazonaws.com
    - ${local.environment_data_s3_bucket_name}.s3.amazonaws.com
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

  provider:
    name: aws
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

  provider:
    name: aws
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

  provider:
    name: aws
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
  depends_on = [
    module.cluster,
    time_sleep.wait_1_minutes_after_cluster
  ]
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
# Note: this module is used to pull secrets from hashicorp vault. It is also used by the external-secrets operator to push secrets to hashicorp vault.
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
  audience        = ""
  environment     = var.load_environment == "" ? local.environment : var.load_environment
}

resource "kubectl_manifest" "gp2-storageclass" {
  depends_on = [
    module.cluster,
    time_sleep.wait_1_minutes_after_cluster
  ]
  yaml_body = <<YAML
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp2
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
parameters:
  fsType: ext4
  type: gp2
provisioner: kubernetes.io/aws-ebs
volumeBindingMode: WaitForFirstConsumer
YAML
  lifecycle {
    ignore_changes = [
      yaml_body
    ]
  }
}

module "karpenter" {
  count = var.karpenter_enabled == true ? 1 : 0
  depends_on = [
    module.cluster,
    time_sleep.wait_1_minutes_after_cluster
  ]
  source               = "./modules/common/karpenter"
  cluster_name         = var.label
  node_role_arn        = local.environment_node_role_arn
  node_role_name       = local.environment_node_role_name
  k8s_version          = var.k8s_version
  az_count             = var.az_count
  subnet_ids           = flatten([local.environment_private_subnet_ids])
  security_group_ids   = distinct(compact(concat([module.cluster.node_security_group_id], var.network_module == "networking" ? [local.environment_all_subnets_sg_id] : [], [module.cluster.cluster_security_group_id])))
  helm_registry        = var.ipa_repo
  karpenter_version    = var.karpenter_version
  default_tags         = var.default_tags
  instance_volume_size = var.instance_volume_size
  instance_volume_type = var.instance_volume_type
  kms_key_id           = local.environment_kms_key_arn
  node_pools           = local.node_pools
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

  indico_storage_class_values = var.include_fsx ? [<<EOF
storage:
  indicoStorageClass:
    enabled: true
    name: ${var.indico_storage_class_name}
    provisioner: fsx.csi.aws.com
    parameters:
      securityGroupIds: ${local.security_group_id}
      subnetId: ${local.environment_fsx_rwx_subnet_id}
EOF
    ] : var.include_efs ? [<<EOF
storage:
  indicoStorageClass:
    enabled: true
    name: ${var.indico_storage_class_name}
    provisioner: efs.csi.aws.com
    parameters:
      provisioningMode: efs-ap
      fileSystemId: ${local.environment_efs_filesystem_id}
      directoryPerms: "700"
      gidRangeStart: "1000"
      gidRangeEnd: "2000"
      basePath: "/dynamic_provisioning"
EOF
    ] : [<<EOF
storage:
  indicoStorageClass:
    enabled: false
EOF
  ]


  indico_pre_reqs_values = concat(local.indico_storage_class_values, [<<EOF
global:
  host: ${local.dns_name}
  image:
    registry: ${var.image_registry}
trust-manager:
  app:
    trust:
      namespace: indico
  image:
    repository: ${var.image_registry}/quay.io/jetstack/trust-manager
  defaultPackageImage:
    repository: ${var.image_registry}/quay.io/jetstack/trust-pkg-debian-bookworm
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
    repository: ${var.image_registry}/public.ecr.aws/efs-csi-driver/amazon/aws-efs-csi-driver
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
    vpcId: ${local.environment_indico_vpc_id}
    region: ${var.region}
cluster-autoscaler:
  enabled: ${var.karpenter_enabled == false ? true : false}
  cluster-autoscaler:
    awsRegion: ${var.region}
    image:
      repository: ${var.image_registry}/public-gcr-k8s-proxy/autoscaling/cluster-autoscaler
      tag: "v${var.k8s_version}.0"
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
externalSecretStore:
  enabled: ${var.secrets_operator_enabled}
  vaultAddress: ${var.vault_address}
  vaultMountPath: ${var.secrets_operator_enabled == true ? module.secrets-operator-setup[0].vault_mount_path : "unused-mount"}
  vaultPath: customer-${var.aws_account}
  vaultRole: ${var.secrets_operator_enabled == true ? module.secrets-operator-setup[0].vault_auth_role_name : "unused-role"}
  vaultServiceAccount: ${var.secrets_operator_enabled == true ? module.secrets-operator-setup[0].vault_auth_service_account_name : "vault-sa"}
  vaultSecretName: "vault-auth"
  EOF
  ])

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
    module.secrets-operator-setup,
    kubectl_manifest.gp2-storageclass,
    module.karpenter
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
  indico_crds_values_yaml_b64      = var.indico-crds-values-yaml-b64
  indico_crds_values_overrides     = local.indico_crds_values
  indico_pre_reqs_version          = var.indico_pre_reqs_version
  indico_pre_reqs_values_overrides = local.indico_pre_reqs_values
  indico_pre_reqs_values_yaml_b64  = var.indico-pre-reqs-values-yaml-b64
  monitoring_enabled               = var.monitoring_enabled
  monitoring_values                = local.monitoring_values
  monitoring_version               = var.monitoring_version
}



# With the common charts are installed, we can then move on to installing intake and/or insights
locals {
  internal_elb = var.network_allow_public == false ? true : false
  backend_port = var.acm_arn != "" ? "http" : "https"
  enableHttp   = var.acm_arn != "" || var.use_nlb == true ? false : true
  loadbalancer_annotation_config = var.create_nginx_ingress_security_group == true && local.environment_nginx_ingress_allowed_cidrs != [] ? (<<EOT
annotations:
  service.beta.kubernetes.io/aws-load-balancer-security-groups: "${local.environment_nginx_ingress_security_group_id}"
  EOT
    ) : (<<EOT
annotations: {}
  EOT
  )
  lb_config = var.acm_arn != "" ? local.acm_loadbalancer_config : local.loadbalancer_config
  loadbalancer_config = var.use_nlb == true ? (<<EOT
      ${indent(6, local.loadbalancer_annotation_config)}
      external:
        enabled: ${var.network_allow_public}
        annotations:
          service.beta.kubernetes.io/aws-load-balancer-backend-protocol: tcp
          service.beta.kubernetes.io/aws-load-balancer-connection-idle-timeout: '60'
          service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: 'true'
          service.beta.kubernetes.io/aws-load-balancer-type: nlb
          service.beta.kubernetes.io/aws-load-balancer-ssl-ports: "https"
      internal:
        enabled: ${local.internal_elb}
        annotations:
          # Create internal NLB
          service.beta.kubernetes.io/aws-load-balancer-backend-protocol: tcp
          service.beta.kubernetes.io/aws-load-balancer-connection-idle-timeout: '60'
          service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: 'true'
          service.beta.kubernetes.io/aws-load-balancer-type: nlb
          service.beta.kubernetes.io/aws-load-balancer-ssl-ports: "https"
          service.beta.kubernetes.io/aws-load-balancer-internal: "${local.internal_elb}"
          service.beta.kubernetes.io/aws-load-balancer-subnets: "${var.internal_elb_use_public_subnets ? join(", ", local.environment_public_subnet_ids) : join(", ", local.environment_private_subnet_ids)}"
  EOT
    ) : (<<EOT
      ${indent(6, local.loadbalancer_annotation_config)}
      external:
        enabled: ${var.network_allow_public}
      internal:
        enabled: ${local.internal_elb}
        annotations:
          # Create internal ELB
          service.beta.kubernetes.io/aws-load-balancer-internal: "${local.internal_elb}"
          service.beta.kubernetes.io/aws-load-balancer-subnets: "${var.internal_elb_use_public_subnets ? join(", ", local.environment_public_subnet_ids) : join(", ", local.environment_private_subnet_ids)}"
  EOT
  )
  acm_loadbalancer_config = (<<EOT
      ${indent(6, local.loadbalancer_annotation_config)}
      external:
        enabled: ${var.network_allow_public}
        annotations:
          service.beta.kubernetes.io/aws-load-balancer-backend-protocol: tcp
          service.beta.kubernetes.io/aws-load-balancer-connection-idle-timeout: '60'
          service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: 'true'
          service.beta.kubernetes.io/aws-load-balancer-type: nlb
          service.beta.kubernetes.io/aws-load-balancer-ssl-ports: "https"
      internal:
        enabled: ${local.internal_elb}
        annotations:
          # Create internal NLB
          service.beta.kubernetes.io/aws-load-balancer-backend-protocol: http
          service.beta.kubernetes.io/aws-load-balancer-connection-idle-timeout: '60'
          service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: 'true'
          service.beta.kubernetes.io/aws-load-balancer-type: nlb
          service.beta.kubernetes.io/aws-load-balancer-ssl-ports: "https"
          service.beta.kubernetes.io/aws-load-balancer-ssl-cert: "${var.acm_arn}"
          service.beta.kubernetes.io/aws-load-balancer-internal: "${local.internal_elb}"
          service.beta.kubernetes.io/aws-load-balancer-subnets: "${var.internal_elb_use_public_subnets ? join(", ", local.environment_public_subnet_ids) : join(", ", local.environment_private_subnet_ids)}"
  EOT
  )
  alerting_configuration_values = var.alerting_enabled == false ? (<<EOT
noExtraConfigs: true
  EOT
    ) : (<<EOT
alerting:
  enabled: true
  email:
    enabled: ${var.alerting_email_enabled}
    smarthost: '${var.alerting_email_host}'
    from: '${var.alerting_email_from}'
    auth_username: '${var.alerting_email_username}'
    auth_password: '${var.alerting_email_password}'
    targetEmail: "${var.alerting_email_to}"
  slack:
    enabled: ${var.alerting_slack_enabled}
    apiUrl: ${var.alerting_slack_token}
    channel: ${var.alerting_slack_channel}
  pagerDuty:
    enabled: ${var.alerting_pagerduty_enabled}
    integrationKey: ${var.alerting_pagerduty_integration_key}
    integrationUrl: "https://events.pagerduty.com/generic/2010-04-15/create_event.json"
${local.standard_rules}
EOT
  )
  standard_rules = var.alerting_standard_rules != "" ? (<<EOT
  standardRules:
    ${indent(4, base64decode(var.alerting_standard_rules))}
EOT
    ) : (<<EOT
  noExtraConfigs: true
  EOT
  )
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
    service:
      metadata:
        labels:
          mirror.linkerd.io/exported: "remote-discovery"
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
        repo1-s3-kms-key-id: "${local.environment_kms_key_arn}"
        repo1-s3-role: ${local.environment_node_role_name}
      repos:
      - name: repo1
        s3:
          bucket: ${local.environment_pgbackup_s3_bucket_name}
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
    persistence:
      storageClass: ${var.include_efs ? var.indico_storage_class_name : ""}
externalSecretStore:
  enabled: ${var.secrets_operator_enabled}
  loadEnvironment:
    enabled: ${var.load_environment == "" ? "false" : "true" }
    environment: ${var.load_environment == "" ? local.environment : var.load_environment}
  EOF
  ])

  intake_values = <<EOF
global:
  image:
    registry: ${var.local_registry_enabled ? "local-registry.${local.dns_name}" : "${var.image_registry}"}/indico
${local.local_registry_tf_cod_values}
secrets:
  general:
    create: ${var.enable_data_application_cluster_separation ? var.load_environment == "" ? "true" : "false" : "true"}
  fernet:
    create: ${var.enable_data_application_cluster_separation ? var.load_environment == "" ? "true" : "false" : "true"}
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
      repository: ${var.local_registry_enabled ? "local-registry.${local.dns_name}" : "${var.image_registry}"}/public.ecr.aws/aws-ec2/aws-node-termination-handler
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
  enabled: ${var.load_environment == "" ? "true" : "false" }
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
worker:
  enabled: ${var.enable_data_application_cluster_separation ? var.load_environment == "" ? "false" : "true" : "true"}
server:
  enabled: ${var.enable_data_application_cluster_separation ? var.load_environment == "" ? "false" : "true" : "true"}
rainbow-nginx:
  enabled: ${var.enable_data_application_cluster_separation ? var.load_environment == "" ? "false" : "true" : "true"}
readapi:
  enabled: ${var.enable_data_application_cluster_separation ? var.load_environment == "" ? "false" : "true" : "true"}
migrations:
  enabled: ${var.enable_data_application_cluster_separation ? var.load_environment == "" ? "false" : "true" : "true"}
${local.faust_worker_settings}
${local.alb_ipa_values}
cronjob:
  enabled: true
  services:
    kafka-connect-supervisor:
      enabled: ${var.enable_data_application_cluster_separation ? var.load_environment == "" ? "true" : "false" : "true"}
    meteor-refresh:
      enabled: ${var.enable_data_application_cluster_separation ? var.load_environment == "" ? "true" : "false" : "true"}
    rainbow-cleaner-submissions:
      enabled: ${var.enable_data_application_cluster_separation ? var.load_environment == "" ? "false" : "true" : "true"}
    rainbow-cleaner-uploads:
      enabled: ${var.enable_data_application_cluster_separation ? var.load_environment == "" ? "false" : "true" : "true"}
    service-account-generator:
      enabled: ${var.enable_data_application_cluster_separation ? var.load_environment == "" ? "false" : "true" : "true"}
externalSecretStore:
  enabled: ${var.secrets_operator_enabled}
  loadEnvironment:
    enabled: ${var.load_environment == "" ? "false" : "true"}
    environment: ${var.load_environment == "" ? local.environment : var.load_environment}
  EOF

  faust_worker_settings = var.enable_data_application_cluster_separation ? var.load_environment == "" ? (<<EOF
faust-worker:
  enabled: true
  volumeMounts:
    - mountPath: /mnt/submission
      name: meteor-data
      subPath: rainbow/submission

    - mountPath: /mnt/data/
      name: meteor-data
      subPath: meteor

  volumes:
    - name: meteor-data
      persistentVolumeClaim:
        claimName: read-write

  services:
    meteor-worker:
      app: meteor
      command: [scripts/worker_entrypoint.sh]
      enabled: true
      livenessProbe:
        initialDelaySeconds: 15
        periodSeconds: 10
        command:
          httpGet:
            path: /live
            port: 6066
      readinessProbe:
        initialDelaySeconds: 15
        timeoutSeconds: 5
        periodSeconds: 15
        command:
          httpGet:
            path: /ready
            port: 6066
      image:
        repository: meteor
      env:
        POSTGRES_APP_SCHEMA: public
        POSTGRES_DB_SCHEMA: public
        SCHEMA_REGISTRY_URL: http://schema-registry-svc:8081
        BOOTSTRAP_SERVERS: kafka-kafka-bootstrap:9092
        SAME_DIR: 'True'
        SUNBOW_HOST: 'http://sunbow-application-cluster:5000'
        DOCTOR_HOST: 'http://doctor-application-cluster:5000'
        NOCT_HOST: 'http://noct-application-cluster:5000'
EOF
) : (<<EOF
faust-worker:
  enabled: false
EOF
) : (<<EOF
faust-worker:
  enabled: true
EOF
)
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

resource "random_password" "minio-password" {
  count   = var.insights_enabled ? 1 : 0
  length  = 16
  special = false
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
        repo2-s3-kms-key-id: "${local.environment_kms_key_arn}"
        repo2-s3-role: ${local.environment_node_role_name}
      repos:
      - name: repo2
        s3:
          bucket: ${local.environment_pgbackup_s3_bucket_name}
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
  storage:
    accessKey: insights
    secretKey: ${var.insights_enabled ? random_password.minio-password[0].result : ""}
  backup:
    enabled: ${var.include_miniobkp}
    schedule: "0 4 * * 2" # This schedules the job to run at 4:00 AM every Tuesday
    localBackup: false
    image:
      repository: harbor.devops.indico.io/docker.io/amazon/aws-cli
      tag: 2.22.4
    awsBucket: ${local.environment_miniobkp_s3_bucket_name}
weaviate:
  cronjob:
    services:
      weaviate-backup:
        enabled: true
  backupStorageConfig:
    accessKey: insights
    secretKey: ${var.insights_enabled ? random_password.minio-password[0].result : ""}
    url: http://minio-tenant-hl.insights.svc.cluster.local:9000
  weaviate:
    env:
      # 1 less than the hard limit of the weaviate node group type
      GOMEMLIMIT: "31GiB"
    # TODO: switch this to a dedicated weaviate backup bucket
    backups:
      s3:
        enabled: true
        envconfig:
          BACKUP_S3_ENDPOINT: minio-tenant-hl.insights.svc.cluster.local:9000
        secrets:
          AWS_ACCESS_KEY_ID: insights
          AWS_SECRET_ACCESS_KEY: ${var.insights_enabled ? random_password.minio-password[0].result : ""}
rabbitmq:
  rabbitmq:
    image:
      registry: ${var.image_registry}
    persistence:
      storageClass: ${var.include_efs ? var.indico_storage_class_name : ""}
  EOF
  ]

  insights_values = <<EOF
global:
  host: ${lower("${var.label}.${var.region}.${var.aws_account}.indico.io")}
  features:
    askMyDocument: true
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
  argo_application_name               = lower("${var.aws_account}.${var.region}.${var.label}-insights")
  vault_path                          = "tools/argo/data/ipa-deploy"
  argo_server                         = module.cluster.kubernetes_host
  argo_project_name                   = var.argo_enabled ? module.argo-registration[0].argo_project_name : ""
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
  helm_values            = trimspace(base64decode(each.value.values))
}


resource "argocd_application" "ipa" {
  depends_on = [
    # local_file.kubeconfig,
    module.intake,
    module.insights,
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
    command = "${path.module}/validate_chart.sh terraform-smoketests 0.1.1-${replace(data.external.git_information.result.branch, "/", "-")}-${substr(data.external.git_information.result.sha, 0, 8)}"
  }
}

output "harbor-api-token" {
  sensitive = true
  value     = var.argo_enabled == true ? jsondecode(data.vault_kv_secret_v2.harbor-api-token[0].data_json)["bearer_token"] : ""
}

output "smoketest_chart_version" {
  value = "${path.module}/validate_chart.sh terraform-smoketests 0.1.1-${replace(data.external.git_information.result.branch, "/", "-")}-${substr(data.external.git_information.result.sha, 0, 8)}"
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

  depends_on = [module.efs-storage[0]]

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
  file_system_id = local.environment_efs_filesystem_id
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
    module.efs-storage[0]
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
        volume_handle = "${local.environment_efs_filesystem_id}::${aws_efs_access_point.local-registry[0].id}"
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

resource "kubernetes_secret" "issuer-secret" {
  depends_on = [
    module.cluster,
    time_sleep.wait_1_minutes_after_cluster
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

# Service mesh
locals {

  linkerd_crds_values = var.enable_service_mesh ? [<<EOF
linkerd-crds:
  enabled: true
EOF
  ] : []

  linkerd_control_plane_values = var.enable_service_mesh ? [<<EOF
linkerd-control-plane:
  enabled: true
  imagePullSecrets:
    - name: harbor-pull-secret
  controllerImage: ${var.image_registry}/cr.l5d.io/linkerd/controller
  policyController:
    name: ${var.image_registry}/cr.l5d.io/linkerd/policy-controller
  proxy:
    name: ${var.image_registry}/cr.l5d.io/linkerd/proxy
  proxyInit:
    name: ${var.image_registry}/cr.l5d.io/linkerd/proxy-init
  debugContainer:
    name: ${var.image_registry}/cr.l5d.io/linkerd/debug
  identity:
    externalCA: true
    issuer:
      scheme: kubernetes.io/tls
EOF
  ] : []

  linkerd_viz_values = var.enable_service_mesh ? [<<EOF
linkerd-viz:
  enabled: true
  defaultRegistry: ${var.image_registry}/cr.l5d.io/linkerd
  imagePullSecrets:
    - name: harbor-pull-secret
EOF
  ] : []

  linkerd_multicluster_values = var.enable_service_mesh ? [<<EOF
linkerd-multicluster:
  enabled: true
  imagePullSecrets:
    - name: harbor-pull-secret
  pauseImage: ${var.image_registry}/gcr.io/google_containers/pause:3.2
  namespaceMetadata:
    registry: ${var.image_registry}/cr.l5d.io/linkerd
  localServiceMirror:
    image:
      name: ${var.image_registry}/cr.l5d.io/linkerd/controller
  controllerDefaults:
    image:
      name: ${var.image_registry}/cr.l5d.io/linkerd/controller
EOF
  ] : []

}

module "service-mesh" {
  depends_on = [
    module.indico-common,
    module.intake,
    module.insights
  ]
  source                        = "./modules/common/service-mesh"
  count                         = var.enable_service_mesh ? 1 : 0
  namespace                     = "indico"
  service_mesh_namespace        = "linkerd"
  linkerd_crds_version          = var.linkerd_crds_version
  linkerd_control_plane_version = var.linkerd_control_plane_version
  linkerd_viz_version           = var.linkerd_viz_version
  linkerd_multicluster_version  = var.linkerd_multicluster_version
  linkerd_crds_values           = local.linkerd_crds_values
  linkerd_control_plane_values  = local.linkerd_control_plane_values
  linkerd_viz_values            = local.linkerd_viz_values
  linkerd_multicluster_values   = local.linkerd_multicluster_values
  helm_registry                 = var.ipa_repo
  load_environment              = var.load_environment
  environment                   = local.environment
  account_name                  = var.aws_account
  label                         = var.label
  image_registry                = var.image_registry
  insights_enabled              = var.insights_enabled
}
