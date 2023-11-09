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
    thanosServiceMonitor:
      enabled: true
    thanosIngress:
      enabled: true
      ingressClassName: nginx
      labels:
        acme.cert-manager.io/dns01-solver: "true"
      annotations:
        cert-manager.io/cluster-issuer: zerossl
        nginx.ingress.kubernetes.io/backend-protocol: GRPC
        nginx.ingress.kubernetes.io/force-ssl-redirect: 'true'
        nginx.ingress.kubernetes.io/grpc-backend: 'true'
        nginx.ingress.kubernetes.io/protocol: h2c
        nginx.ingress.kubernetes.io/proxy-read-timeout: '160'
      
      pathType: ImplementationSpecific
      paths:
        - /
      hosts:
        - "thanos.${local.dns_name}"
      tls:
        - secretName: thanos-gateway-tls
          hosts:
            - "thanos.${local.dns_name}"
    thanosServiceExternal:
      enabled: true
      annotations:
        external-dns.alpha.kubernetes.io/hostname: sidecar.${local.dns_name}

    thanosService:
      #annotations:
      #  external-dns.alpha.kubernetes.io/hostname: thanos.${local.dns_name}
      enabled: true

    prometheusSpec:
      externalLabels:
        clusterAccount: ${var.aws_account}
        clusterRegion: ${var.region}
        clusterName: ${var.label}
        clusterFullName: ${lower("${var.aws_account}-${var.region}-${var.name}")}
      volumes:
        - secret:
            secretName: thanos-gateway-tls
          name: thanos-gateway-tls
      thanos: 
        volumeMounts:
          - mountPath: /etc/tls/grpc
            name: thanos-gateway-tls
        grpcServerTlsConfig:
          certFile: "/etc/tls/grpc/tls.crt"
          keyFile: "/etc/tls/grpc/tls.key"
        additionalArgs:
          - --grpc-client-tls-secure
          - --grpc-client-tls-skip-verify
          - --endpoint=thanos.${local.dns_name}:443
        objectStorageConfig:
          existingSecret:
            name: thanos-storage
            key: thanos_storage.yaml

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
    thanosServiceMonitor:
      enabled: true

    thanosService:
      enabled: true
    
    prometheusSpec:
      disableCompaction: true
      additionalArgs:
        - "--storage.tsdb.min-block-duration=5m"
        - "--storage.tsdb.max-block-duration=5m"
      externalLabels:
        clusterAccount: ${var.aws_account}
        clusterRegion: ${var.region}
        clusterName: ${var.label}
        clusterFullName: ${lower("${var.aws_account}-${var.region}-${var.name}")}
      thanos: # this is the one being used
        objectStorageConfig:
          existingSecret:
            name: thanos-storage
            key: thanos_storage.yaml
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

resource "aws_route53_record" "grafana-caa" {
  count   = var.monitoring_enabled == true && var.is_alternate_account_domain == "false" ? 1 : 0
  zone_id = data.aws_route53_zone.primary.zone_id
  name    = lower("grafana.${local.dns_name}")
  type    = "CAA"
  ttl     = 300
  records = [
    "0 issue \"sectigo.com\""
  ]
}


resource "aws_route53_record" "prometheus-caa" {
  count   = var.monitoring_enabled == true && var.is_alternate_account_domain == "false" ? 1 : 0
  zone_id = data.aws_route53_zone.primary.zone_id
  name    = lower("prometheus.${local.dns_name}")
  type    = "CAA"
  ttl     = 300
  records = [
    "0 issue \"sectigo.com\""
  ]
}

resource "aws_route53_record" "alertmanager-caa" {
  count   = var.monitoring_enabled == true && var.is_alternate_account_domain == "false" ? 1 : 0
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
  skip_crds        = true

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

${local.alerting_configuration_values}

kube-prometheus-stack:
${local.kube_prometheus_stack_values}

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

