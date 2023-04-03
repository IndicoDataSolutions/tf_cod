resource "azurerm_dns_caa_record" "grafana-caa" {
  count               = var.monitoring_enabled == true && local.kube_prometheus_stack_enabled == true ? 1 : 0
  name                = lower("grafana.${local.dns_prefix}")
  zone_name           = data.azurerm_dns_zone.domain.name
  resource_group_name = var.common_resource_group
  ttl                 = 300
  record {
    flags = 0
    tag   = "issue"
    value = "sectigo.com"
  }
}


resource "azurerm_dns_caa_record" "prometheus-caa" {
  count               = var.monitoring_enabled == true && local.kube_prometheus_stack_enabled == true ? 1 : 0
  name                = lower("prometheus.${local.dns_prefix}")
  zone_name           = data.azurerm_dns_zone.domain.name
  resource_group_name = var.common_resource_group
  ttl                 = 300

  record {
    flags = 0
    tag   = "issue"
    value = "sectigo.com"
  }
}


resource "azurerm_dns_caa_record" "alertmanager-caa" {
  count               = var.monitoring_enabled == true && local.kube_prometheus_stack_enabled == true ? 1 : 0
  name                = lower("alertmanager.${local.dns_prefix}")
  zone_name           = data.azurerm_dns_zone.domain.name
  resource_group_name = var.common_resource_group
  ttl                 = 300

  record {
    flags = 0
    tag   = "issue"
    value = "sectigo.com"
  }
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
    azurerm_dns_caa_record.alertmanager-caa,
    azurerm_dns_caa_record.grafana-caa,
    azurerm_dns_caa_record.prometheus-caa,
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
  
  prometheus-postgres-exporter:
    enabled: ${local.kube_prometheus_stack_enabled}

  ingress-nginx:
    enabled: ${local.kube_prometheus_stack_enabled}

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
    enabled: ${local.kube_prometheus_stack_enabled}
    prometheus:
      prometheusSpec:
        nodeSelector:
          node_group: static-workers
        storageSpec:
          volumeClaimTemplate:
            spec:
              storageClassName: default

  prometheus-adapter:
    enabled: false
 EOF
  ]
}

resource "helm_release" "keda-monitoring" {
  count = !var.is_openshift == true && var.monitoring_enabled == true ? 1 : 0
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
        serviceMonitor:
          enabled: true
        podMonitor:
          enabled: true
      operator:
        enabled: true
        serviceMonitor:
          enabled: true
        podMonitor:
          enabled: true
 EOF
  ]
}

resource "helm_release" "opentelemetry-collector" {
  count = local.kube_prometheus_stack_enabled == true ? 1 : 0
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

resource "kubectl_manifest" "pod-security-admission-controller" {
  depends_on = [
    module.cluster
  ]
  count = var.enable_pod_security == true ? 1 : 0
  yaml_body = <<YAML
apiVersion: apiserver.config.k8s.io/v1 # see compatibility note
kind: AdmissionConfiguration
plugins:
- name: PodSecurity
  configuration:
    apiVersion: pod-security.admission.config.k8s.io/v1
    kind: PodSecurityConfiguration
    # Defaults applied when a mode label is not set.
    #
    # Level label values must be one of:
    # - "privileged" (default)
    # - "baseline"
    # - "restricted"
    #
    # Version label values must be one of:
    # - "latest" (default) 
    # - specific version like "v1.26"
    defaults:
      enforce: "privileged"
      enforce-version: "latest"
      audit: "privileged"
      audit-version: "latest"
      warn: "privileged"
      warn-version: "latest"
    exemptions:
      # Array of authenticated usernames to exempt.
      usernames: []
      # Array of runtime class names to exempt.
      runtimeClasses: []
      # Array of namespaces to exempt.
      namespaces: []
YAML
}