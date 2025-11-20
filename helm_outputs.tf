output "ipa_crds_helm_values" {
  sensitive = true
  value     = <<EOF
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
}

locals {
  pre_reqs_efs_values = var.include_efs == true ? [<<EOF
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
  pre_reqs_fsx_values = var.include_fsx == true ? [<<EOF
  aws-fsx-csi-driver:
    enabled: true
  aws-efs-csi-driver:
    enabled: false
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
  pre_reqs_storage_spec = var.include_fsx == true ? local.pre_reqs_fsx_values : local.pre_reqs_efs_values
}

output "ipa_pre_reqs_helm_values" {
  sensitive = true
  value = concat(local.pre_reqs_storage_spec, [<<EOF

cluster:
  name: ${var.label}
  region: ${var.region}
  domain: indico.io
  account: ${var.aws_account}

secrets:
  rabbitmq:
    create: true
  
  general:
    create: true

  clusterIssuer:
    zerossl:
      create: true
      eabEmail: devops-sa@indico.io
      eabKid: "${var.zerossl_key_id}"
      eabHmacKey: "${var.zerossl_hmac_base64}"
     
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
  enabled: true
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

cluster-autoscaler:
  cluster-autoscaler:
    awsRegion: ${var.region}
    image:
      tag: "v1.20.0"
    autoDiscovery:
      clusterName: "${local.cluster_name}"

aws-load-balancer-controller:
  enabled: ${var.use_acm}
  aws-load-balancer-controller:
    clusterName: ${var.label}
    vpcId: ${local.network[0].indico_vpc_id}
    region: ${var.region}
EOF
  ])
}
