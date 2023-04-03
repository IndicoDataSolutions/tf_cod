resource "azurerm_dns_caa_record" "grafana-caa" {
  count               = var.enable_dns_infrastructure == true && var.enable_monitoring_infrastructure == true ? 1 : 0
  name                = lower("grafana.${var.dns_prefix}")
  zone_name           = data.azurerm_dns_zone.domain.0.name
  resource_group_name = var.common_resource_group
  ttl                 = 300
  record {
    flags = 0
    tag   = "issue"
    value = "sectigo.com"
  }
}


resource "azurerm_dns_caa_record" "prometheus-caa" {
  count               = var.enable_dns_infrastructure == true && var.enable_monitoring_infrastructure == true ? 1 : 0
  name                = lower("prometheus.${var.dns_prefix}")
  zone_name           = data.azurerm_dns_zone.domain.0.name
  resource_group_name = var.common_resource_group
  ttl                 = 300

  record {
    flags = 0
    tag   = "issue"
    value = "sectigo.com"
  }
}

resource "azurerm_dns_caa_record" "alertmanager-caa" {
  count               = var.enable_dns_infrastructure == true && var.enable_monitoring_infrastructure == true ? 1 : 0
  name                = lower("alertmanager.${var.dns_prefix}")
  zone_name           = data.azurerm_dns_zone.domain.0.name
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


resource "null_resource" "replace-prometheus-crds" {
  count = var.replace_prometheus_crds == true ? 1 : 0

  # login
  #triggers = {
  #  always_run = "${timestamp()}"
  #}

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "${path.module}/auth.sh ${var.label} ${var.resource_group_name}"
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "kubectl scale deployment/cluster-version-operator -n openshift-cluster-version --replicas=0"
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "kubectl scale deploy -n openshift-monitoring prometheus-operator --replicas=0"
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "kubectl scale deploy -n openshift-monitoring cluster-monitoring-operator --replicas=0"
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "kubectl replace -f ${path.module}/prometheus-crds --force"
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "oc adm policy add-scc-to-group anyuid system:authenticated"
  }
}

resource "helm_release" "monitoring" {
  count = var.enable_monitoring_infrastructure == true ? 1 : 0
  depends_on = [
    helm_release.ipa-crds,
    null_resource.replace-prometheus-crds,
    azurerm_dns_caa_record.alertmanager-caa,
    azurerm_dns_caa_record.grafana-caa,
    azurerm_dns_caa_record.prometheus-caa
  ]

  name             = "monitoring"
  create_namespace = true
  namespace        = var.monitoring_namespace
  repository       = var.ipa_repo
  chart            = "monitoring"
  version          = var.monitoring_version
  timeout          = "900" # 15 minutes

  values = [<<EOF
  global:
    host: "${var.dns_name}"
  
  prometheus-postgres-exporter:
    enabled: false

  ingress-nginx:
    enabled: ${var.enable_dns_infrastructure == true && var.enable_monitoring_infrastructure == true}

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
    enabled: true
    nodeExporter:
      enabled: false

    prometheus:
      enabled: true
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

resource "null_resource" "restore-prometheus-operator" {
  count = var.replace_prometheus_crds == true ? 1 : 0

  depends_on = [
    helm_release.monitoring
  ]



  # login
  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "${path.module}/auth.sh ${var.label} ${var.resource_group_name}"
  }

  #provisioner "local-exec" {
  #  interpreter = ["/bin/bash", "-c"]
  #  command     = "kubectl scale deployment/cluster-version-operator -n openshift-cluster-version --replicas=1"
  #}

  #provisioner "local-exec" {
  #  interpreter = ["/bin/bash", "-c"]
  #  command     = "kubectl scale deploy -n openshift-monitoring cluster-monitoring-operator --replicas=1"
  #}

  #provisioner "local-exec" {
  #  interpreter = ["/bin/bash", "-c"]
  #  command     = "kubectl scale deploy -n openshift-monitoring prometheus-operator --replicas=1"
  #}
}


resource "helm_release" "keda-monitoring" {
  count = var.enable_monitoring_infrastructure == true ? 1 : 0
  depends_on = [
    null_resource.restore-prometheus-operator,
    helm_release.monitoring,
    null_resource.replace-prometheus-crds,
  ]

  name             = "keda"
  create_namespace = true
  namespace        = var.monitoring_namespace
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
  count = var.enable_monitoring_infrastructure == true ? 1 : 0
  depends_on = [
    helm_release.monitoring,
    null_resource.replace-prometheus-crds,
  ]

  name             = "opentelemetry-collector"
  create_namespace = true
  namespace        = var.monitoring_namespace
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
          endpoint: monitoring-tempo.${var.monitoring_namespace}.svc:4317
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
  count = var.enable_pod_security == true ? 1 : 0
  # Note: pod-security.admission.config.k8s.io/v1 configuration requires v1.25+. For v1.23 and v1.24, use v1beta1. For v1.22, use v1alpha1.
  yaml_body = <<YAML
apiVersion: apiserver.config.k8s.io/v1beta1 # see compatibility note
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