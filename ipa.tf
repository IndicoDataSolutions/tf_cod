resource "helm_release" "ipa-pre-requisites" {
  depends_on = [
    module.cluster
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