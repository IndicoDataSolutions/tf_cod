locals {
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
        - alertmanager-${var.dns_name}
      paths:
        - /
      tls:
        - secretName: ${var.ssl_static_secret_name}
          hosts:
            - alertmanager-${var.dns_name}
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
        clusterAccount: ${var.aws_account}
        clusterRegion: ${var.region}
        clusterName: ${var.label}
        clusterFullName: ${lower("${var.aws_account}-${var.region}-${var.label}")}
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
        - prometheus-${var.dns_name}
      paths:
        - /
      tls:
        - secretName: ${var.ssl_static_secret_name}
          hosts:
            - prometheus-${var.dns_name}
  grafana:
    ingress:
      annotations:
        cert-manager.io/cluster-issuer: zerossl
      labels:
        acme.cert-manager.io/dns01-solver: "true"
      enabled: true
      ingressClassName: nginx
      hosts:
        - grafana-${var.dns_name}
      path: /
      tls:
        - secretName: ${var.ssl_static_secret_name}
          hosts:
            - grafana-${var.dns_name}
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
        clusterAccount: ${var.aws_account}
        clusterRegion: ${var.region}
        clusterName: ${var.label}
        clusterFullName: ${lower("${var.aws_account}-${var.region}-${var.label}")}
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

resource "random_password" "monitoring-password" {
  length  = 16
  special = false
}

resource "helm_release" "monitoring" {

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
  host: "${var.dns_name}"

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

${local.alerting_configuration_values}
kube-prometheus-stack:
${local.kube_prometheus_stack_values}
EOF
  ]
}

resource "helm_release" "keda-monitoring" {
  depends_on = [
    helm_release.monitoring
  ]

  name             = "keda"
  create_namespace = true
  namespace        = "default"
  repository       = "https://kedacore.github.io/charts"
  chart            = "keda"
  version          = var.keda_version


  values = [<<EOF
    image:
      metricsApiServer:
        repository: harbor.devops.indico.io/ghcr.io/kedacore/keda-metrics-apiserver
      webhooks:
        repository: harbor.devops.indico.io/ghcr.io/kedacore/keda-admission-webhooks
      keda:
        repository: harbor.devops.indico.io/ghcr.io/kedacore/keda
    imagePullSecrets:
      - name: harbor-pull-secret
    resources:
      operator:
        requests:
          memory: 512Mi
        limits:
          memory: 2Gi
        
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
  depends_on = [
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
      repository: harbor.devops.indico.io/docker.io/otel/opentelemetry-collector-contrib
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

