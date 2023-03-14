
resource "helm_release" "indico-admission-controller" {
  count            = var.use_admission_controller == true ? 1 : 0
  name             = "adm"
  create_namespace = true
  namespace        = var.ipa_namespace
  repository       = var.ipa_repo
  chart            = "indico-openshift-adm"
  version          = var.openshift_admission_chart_version
  timeout          = "600" # 10 minutes
  wait             = true
}


resource "helm_release" "indico-admission-webhook" {
  depends_on = [
    helm_release.indico-admission-controller
  ]

  count = var.use_admission_controller == true ? 1 : 0

  name             = "wh"
  create_namespace = true
  namespace        = var.ipa_namespace
  repository       = var.ipa_repo
  chart            = "indico-openshift-webhook"
  version          = var.openshift_webhook_chart_version
  wait             = true
}

