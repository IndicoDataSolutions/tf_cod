
resource "aws_route53_record" "grafana-caa" {
  count   = var.monitoring_enabled == true ? 1 : 0
  zone_id = data.aws_route53_zone.primary.zone_id
  name    = lower("grafana.${local.dns_name}")
  type    = "CAA"
  ttl     = 300
  records = [
    "0 issue \"sectigo.com\""
  ]
}


resource "aws_route53_record" "prometheus-caa" {
  count   = var.monitoring_enabled == true ? 1 : 0
  zone_id = data.aws_route53_zone.primary.zone_id
  name    = lower("prometheus.${local.dns_name}")
  type    = "CAA"
  ttl     = 300
  records = [
    "0 issue \"sectigo.com\""
  ]
}


resource "aws_route53_record" "alertmanager-caa" {
  count   = var.monitoring_enabled == true ? 1 : 0
  zone_id = data.aws_route53_zone.primary.zone_id
  name    = lower("alertmanager.${local.dns_name}")
  type    = "CAA"
  ttl     = 300
  records = [
    "0 issue \"sectigo.com\""
  ]
}


resource "random_password" "monitoring-password" {
  length  = 16
  special = false
}

output "monitoring-username" {
  value = "monitoring"
}

output "monitoring-password" {
  sensitive = true
  value     = random_password.monitoring-password.result
}

resource "helm_release" "monitoring" {
  count = var.monitoring_enabled == true ? 1 : 0
  depends_on = [
    module.cluster,
    helm_release.ipa-pre-requisites,
    aws_route53_record.alertmanager-caa,
    aws_route53_record.grafana-caa,
    aws_route53_record.prometheus-caa
  ]

  verify           = false
  name             = "monitoring"
  create_namespace = true
  namespace        = "monitoring"
  repository       = var.ipa_repo
  chart            = "monitoring"
  version          = var.monitoring_version
  wait             = false
  timeout          = "900" # 15 minutes

  values = [<<EOF
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

 EOF
  ]
}

