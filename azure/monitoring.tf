locals {
  private_dns_config = var.private_dns_zone == true ? (<<EOT

ingress-nginx:
  controller:
    service:
      annotations:
        service.beta.kubernetes.io/azure-load-balancer-internal: "true"
        service.beta.kubernetes.io/azure-load-balancer-internal-subnet: ${module.networking.subnet_name}
  EOT
  ) : ""

  thanos_config = var.thanos_enabled == true ? (<<EOT
      thanos: # this is the one being used
        blockSize: 5m
        objectStorageConfig:
          existingSecret:
            name: thanos-storage
            key: thanos_storage.yaml
  EOT
    ) : (<<EOT
      thanos: {}
  EOT
  )

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


  kube_prometheus_stack_values = var.use_static_ssl_certificates == true ? (<<EOT
  alertmanager:
    ingress:
      annotations:
        cert-manager.io/cluster-issuer: zerossl
      labels:
        acme.cert-manager.io/dns01-solver: "true"
      enabled: true
      ingressClassName: nginx
      hosts:
        - alertmanager-${local.dns_name}
      paths:
        - /
      tls:
        - secretName: ${var.ssl_static_secret_name}
          hosts:
            - alertmanager-${local.dns_name}
  prometheus:
    annotations:
      reloader.stakater.com/auto: "true"

    thanosServiceMonitor:
      enabled: ${var.thanos_enabled}

    thanosService:
      enabled:  ${var.thanos_enabled}

    prometheusSpec:
      disableCompaction: ${var.thanos_enabled}
      externalLabels:
        clusterAccount: ${var.account}
        clusterRegion: ${var.region}
        clusterName: ${var.label}
        clusterFullName: ${lower("${var.account}-${var.region}-${var.name}")}
${local.thanos_config}
      nodeSelector:
        node_group: static-workers
    ingress:
      enabled: true
      annotations:
        cert-manager.io/cluster-issuer: zerossl
      labels:
        acme.cert-manager.io/dns01-solver: "true"
      ingressClassName: nginx
      hosts:
        - prometheus-${local.dns_name}
      paths:
        - /
      tls:
        - secretName: ${var.ssl_static_secret_name}
          hosts:
            - prometheus-${local.dns_name}
  grafana:
    ingress:
      annotations:
        cert-manager.io/cluster-issuer: zerossl
      labels:
        acme.cert-manager.io/dns01-solver: "true"
      enabled: true
      ingressClassName: nginx
      hosts:
        - grafana-${local.dns_name}
      path: /
      tls:
        - secretName: ${var.ssl_static_secret_name}
          hosts:
            - grafana-${local.dns_name}
  EOT
    ) : (<<EOT
  alertmanager:
    ingress:
      annotations:
        cert-manager.io/cluster-issuer: zerossl
      labels:
        acme.cert-manager.io/dns01-solver: "true"

  prometheus:
    annotations:
      reloader.stakater.com/auto: "true"

    thanosServiceMonitor:
      enabled: ${var.thanos_enabled}

    thanosService:
      enabled: ${var.thanos_enabled}
    
    prometheusSpec:
      disableCompaction: ${var.thanos_enabled}
      externalLabels:
        clusterAccount: ${var.account}
        clusterRegion: ${var.region}
        clusterName: ${var.label}
        clusterFullName: ${lower("${var.account}-${var.region}-${var.name}")}
${local.thanos_config}
      nodeSelector:
        node_group: static-workers
    ingress:
      annotations:
        cert-manager.io/cluster-issuer: zerossl
      labels:
        acme.cert-manager.io/dns01-solver: "true"
  grafana:
    ingress:
      annotations:
        cert-manager.io/cluster-issuer: zerossl
      labels:
        acme.cert-manager.io/dns01-solver: "true"
EOT
  )
}

# Public DNS records
resource "azurerm_dns_caa_record" "grafana-caa" {
  count               = var.monitoring_enabled == true && local.kube_prometheus_stack_enabled == true && var.is_alternate_account_domain == "false" && var.private_dns_zone != true ? 1 : 0
  name                = lower("grafana.${local.dns_prefix}")
  zone_name           = local.base_domain
  resource_group_name = var.common_resource_group
  ttl                 = 300
  record {
    flags = 0
    tag   = "issue"
    value = "sectigo.com"
  }
}


resource "azurerm_dns_caa_record" "prometheus-caa" {
  count               = var.monitoring_enabled == true && local.kube_prometheus_stack_enabled == true && var.is_alternate_account_domain == "false" && var.private_dns_zone != true ? 1 : 0
  name                = lower("prometheus.${local.dns_prefix}")
  zone_name           = local.base_domain
  resource_group_name = var.common_resource_group
  ttl                 = 300

  record {
    flags = 0
    tag   = "issue"
    value = "sectigo.com"
  }
}


resource "azurerm_dns_caa_record" "alertmanager-caa" {
  count               = var.monitoring_enabled == true && local.kube_prometheus_stack_enabled == true && var.is_alternate_account_domain == "false" && var.private_dns_zone != true ? 1 : 0
  name                = lower("alertmanager.${local.dns_prefix}")
  zone_name           = local.base_domain
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

resource "azurerm_role_assignment" "private_dns_contributor" {
  count                = var.private_dns_zone ? 1 : 0
  scope                = module.networking.vnet_id
  role_definition_name = "Network Contributor"
  principal_id         = module.cluster.principal_id
}


resource "helm_release" "monitoring" {
  count = var.monitoring_enabled == true ? 1 : 0
  depends_on = [
    module.cluster,
    helm_release.external-secrets,
    helm_release.ipa-pre-requisites,
    azurerm_dns_caa_record.alertmanager-caa,
    azurerm_dns_caa_record.grafana-caa,
    azurerm_dns_caa_record.prometheus-caa,
    time_sleep.wait_1_minutes_after_pre_reqs,
    azurerm_role_assignment.private_dns_contributor
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
  skip_crds        = true

  values = [<<EOF
global:
  host: "${local.dns_name}"

prometheus-postgres-exporter:
  enabled: false

ingress-nginx:
  enabled: ${local.kube_prometheus_stack_enabled}

  rbac:
    create: true

  controller:
    service:
      annotations:
        service.beta.kubernetes.io/azure-load-balancer-health-probe-request-path: /healthz

  admissionWebhooks:
    patch:
      nodeSelector.beta.kubernetes.io/os: linux

    controller:
      service:
        annotations:
          service.beta.kubernetes.io/azure-load-balancer-health-probe-request-path: /healthz
  
  authentication:
    ingressUsername: monitoring
    ingressPassword: ${random_password.monitoring-password.result}


  defaultBackend:
    nodeSelector.beta.kubernetes.io/os: linux

authentication:
  ingressUsername: monitoring
  ingressPassword: ${random_password.monitoring-password.result}

${local.alerting_configuration_values}
kube-prometheus-stack:
${local.kube_prometheus_stack_values}
EOF
    ,
    <<EOF
${local.private_dns_config}
    EOF
  ]
}

resource "kubectl_manifest" "thanos-datasource-credentials" {
  count     = var.thanos_enabled ? 1 : 0
  provider  = kubectl.thanos-kubectl
  yaml_body = <<YAML
apiVersion: v1
stringData:
  admin-password: ${random_password.monitoring-password.result}
kind: Secret
metadata:
  name: ${replace(local.dns_name, ".", "-")}
  namespace: default
type: Opaque
  YAML
}

resource "kubectl_manifest" "thanos-datasource" {
  count      = var.thanos_enabled ? 1 : 0
  depends_on = [kubectl_manifest.thanos-datasource-credentials]
  provider   = kubectl.thanos-kubectl
  yaml_body  = <<YAML
apiVersion: grafana.integreatly.org/v1beta1
kind: GrafanaDatasource
metadata:
  name: ${replace(local.dns_name, ".", "-")}
  namespace: default
spec:
  valuesFrom:
    - targetPath: "secureJsonData.basicAuthPassword"
      valueFrom:
        secretKeyRef:
          name: ${replace(local.dns_name, ".", "-")}
          key: admin-password
  datasource:
    basicAuth: true
    basicAuthUser: monitoring
    editable: false
    access: proxy
    editable: true
    jsonData:
      timeInterval: 5s
      tlsSkipVerify: true
    name: ${local.dns_name}
    secureJsonData:
      basicAuthPassword: $${admin-password}
    type: prometheus
    url: https://prometheus.${local.dns_name}/prometheus
  instanceSelector:
    matchLabels:
      dashboards: external-grafana
  YAML
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
  wait             = true


  values = [<<EOF
    image:
      metricsApiServer:
        repository: ${var.image_registry}/ghcr.io/kedacore/keda-metrics-apiserver
      webhooks:
        repository: ${var.image_registry}/ghcr.io/kedacore/keda-admission-webhooks
      keda:
        repository: ${var.image_registry}/ghcr.io/kedacore/keda
    imagePullSecrets:
      - name: harbor-pull-secret
      
    resources:
      operator:
        requests:
          memory: 512Mi
        limits:
          memory: 4Gi

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
    imagePullSecrets:
      - name: harbor-pull-secret
    image:
      repository: ${var.image_registry}/docker.io/otel/opentelemetry-collector-contrib
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
