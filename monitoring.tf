
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
    aws_route53_record.prometheus-caa,
    time_sleep.wait_1_minutes_after_pre_reqs
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
    commonLabels:
      acme.cert-manager.io/dns01-solver: "true"
    prometheus:
      prometheusSpec:
        nodeSelector:
          node_group: static-workers
      ingress:
        labels: null
    grafana:
      ingress: 
        labels: null
      extraLabels: acme.cert-manager.io/dns01-solver: "true"
    alertmanager:
      ingress: 
        labels: null

 EOF
  ]
}

resource "helm_release" "keda-monitoring" {
  count = var.monitoring_enabled == true ? 1 : 0
  depends_on = [
    module.cluster,
    helm_release.monitoring
  ]

  name             = "keda"
  create_namespace = true
  namespace        = "default"
  repository       = "https://kedacore.github.io/charts"
  chart            = "keda"
  version          = var.keda_version


  values = [<<EOF
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
 EOF
  ]
}

resource "helm_release" "opentelemetry-collector" {
  count = var.monitoring_enabled == true ? 1 : 0
  depends_on = [
    module.cluster,
    helm_release.monitoring
  ]

  name             = "opentelemetry-collector"
  create_namespace = true
  namespace        = "default"
  repository       = "https://open-telemetry.github.io/opentelemetry-helm-charts"
  chart            = "opentelemetry-collector"
  version          = var.opentelemetry-collector_version


  values = [<<EOF
    enabled: true
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
  ]
}

