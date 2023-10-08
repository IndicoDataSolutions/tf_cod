resource "helm_release" "ipa-crds" {
  depends_on = [
    module.cluster
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

# resource "time_sleep" "wait_1_minutes_after_crds" {
#   depends_on = [helm_release.ipa-crds]

#   create_duration = "1m"
# }

resource "helm_release" "ipa-pre-requisites" {
  depends_on = [
    module.cluster,
    helm_release.ipa-crds,
    time_sleep.wait_1_minutes_after_crds,
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
  aws-efs-csi-driver:
    enabled: true
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
        tag: "v1.27.0"
      autoDiscovery:
        clusterName: "${local.cluster_name}"
      
 EOF
  ]
}