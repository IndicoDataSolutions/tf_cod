locals {
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
EOT
  )
}

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
  skip_crds        = true

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
  
  controller:
    service:
      annotations:
        service.beta.kubernetes.io/azure-load-balancer-health-probe-request-path: /healthz

authentication:
  ingressUsername: monitoring
  ingressPassword: ${random_password.monitoring-password.result}

${local.alerting_configuration_values}

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
