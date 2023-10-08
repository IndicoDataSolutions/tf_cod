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
  aws-load-balancer-controller:
    enabled: true
  ingress:
    enabled: true
      
 EOF
  ]
}