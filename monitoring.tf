locals {
  internal_elb = var.network_allow_public == false ? true : false
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
  backend_port = var.acm_arn != "" ? "http" : "https"
  lb_config = var.acm_arn != "" ? local.acm_loadbalancer_config : local.loadbalancer_config
  loadbalancer_config = var.use_nlb == true ? (<<EOT
      external:
        enabled: ${var.network_allow_public}
        annotations:
          service.beta.kubernetes.io/aws-load-balancer-backend-protocol: tcp
          service.beta.kubernetes.io/aws-load-balancer-connection-idle-timeout: '60'
          service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: 'true'
          service.beta.kubernetes.io/aws-load-balancer-type: nlb
          service.beta.kubernetes.io/aws-load-balancer-ssl-ports: "https"
      internal:
        enabled: ${local.internal_elb}
        annotations:
          # Create internal NLB
          service.beta.kubernetes.io/aws-load-balancer-backend-protocol: tcp
          service.beta.kubernetes.io/aws-load-balancer-connection-idle-timeout: '60'
          service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: 'true'
          service.beta.kubernetes.io/aws-load-balancer-type: nlb
          service.beta.kubernetes.io/aws-load-balancer-ssl-ports: "https"
          service.beta.kubernetes.io/aws-load-balancer-internal: "${local.internal_elb}"
          service.beta.kubernetes.io/aws-load-balancer-subnets: "${join(", ", local.network[0].public_subnet_ids)}"
  EOT
  ) : (<<EOT
      external:
        enabled: ${var.network_allow_public}
      internal:
        enabled: ${local.internal_elb}
        annotations:
          # Create internal ELB
          service.beta.kubernetes.io/aws-load-balancer-internal: "${local.internal_elb}"
          service.beta.kubernetes.io/aws-load-balancer-subnets: "${join(", ", local.network[0].public_subnet_ids)}"
  EOT
  )
  acm_loadbalancer_config = (<<EOT
      external:
        enabled: ${var.network_allow_public}
        annotations:
          service.beta.kubernetes.io/aws-load-balancer-backend-protocol: tcp
          service.beta.kubernetes.io/aws-load-balancer-connection-idle-timeout: '60'
          service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: 'true'
          service.beta.kubernetes.io/aws-load-balancer-type: nlb
          service.beta.kubernetes.io/aws-load-balancer-ssl-ports: "https"
      internal:
        enabled: ${local.internal_elb}
        annotations:
          # Create internal NLB
          service.beta.kubernetes.io/aws-load-balancer-backend-protocol: http
          service.beta.kubernetes.io/aws-load-balancer-connection-idle-timeout: '60'
          service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: 'true'
          service.beta.kubernetes.io/aws-load-balancer-type: nlb
          service.beta.kubernetes.io/aws-load-balancer-ssl-ports: "https"
          service.beta.kubernetes.io/aws-load-balancer-ssl-cert: "${var.acm_arn}"
          service.beta.kubernetes.io/aws-load-balancer-internal: "${local.internal_elb}"
          service.beta.kubernetes.io/aws-load-balancer-subnets: "${join(", ", local.network[0].public_subnet_ids)}"
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
  alertmanager_tls = var.acm_arn == "" ? (<<EOT
      tls:
        - secretName: ${var.ssl_static_secret_name}
          hosts:
            - alertmanager-${local.dns_name}
  EOT
  ) : (<<EOT
      tls: []
  EOT
  )
  grafana_tls = var.acm_arn == "" ? (<<EOT
      tls:
        - secretName: ${var.ssl_static_secret_name}
          hosts:
            - grafana-${local.dns_name}
  EOT
  ) : (<<EOT
      tls: []
  EOT
  )
  prometheus_tls = var.acm_arn == "" ? (<<EOT
      tls:
        - secretName: ${var.ssl_static_secret_name}
          hosts:
            - prometheus-${local.dns_name}
  EOT
  ) : (<<EOT
      tls: []
  EOT
  )
  kube_prometheus_stack_values = var.use_static_ssl_certificates == true || var.acm_arn != "" ? (<<EOT
  prometheus-node-exporter:
    image:
      registry: ${var.image_registry}/quay.io
  alertmanager:
    alertmanagerSpec:
      image:
        registry: ${var.image_registry}/quay.io
    ingress:
      enabled: true
      ingressClassName: nginx
      hosts:
        - alertmanager-${local.dns_name}
      paths:
        - /
${local.alertmanager_tls}
  prometheusOperator:
    thanosImage:
      registry:  ${var.image_registry}/quay.io

    prometheusConfigReloader:
      image:
        registry: ${var.image_registry}/quay.io

    prometheusDefaultBaseImageRegistry: ${var.image_registry}/quay.io 
    alertmanagerDefaultBaseImageRegistry: ${var.image_registry}/quay.io 
    image:
      registry: ${var.image_registry}/quay.io

    admissionWebhooks:
      patch:
        image:
          registry: ${var.image_registry}/registry.k8s.io
  kube-state-metrics:
    image:
      registry: ${var.image_registry}/registry.k8s.io
  prometheus:
    annotations:
      reloader.stakater.com/auto: "true"

    thanosServiceMonitor:
      enabled: ${var.thanos_enabled}

    thanosService:
      enabled:  ${var.thanos_enabled}

    prometheusSpec:
      image:
        registry: ${var.image_registry}/quay.io
      disableCompaction: ${var.thanos_enabled}
      externalLabels:
        clusterAccount: ${var.aws_account}
        clusterRegion: ${var.region}
        clusterName: ${var.label}
        clusterFullName: ${lower("${var.aws_account}-${var.region}-${var.name}")}
${local.thanos_config}
      nodeSelector:
        node_group: static-workers
    ingress:
      enabled: true
      ingressClassName: nginx
      hosts:
        - prometheus-${local.dns_name}
      paths:
        - /
${local.prometheus_tls}
  grafana:
    downloadDashboardsImage:
      registry: ${var.image_registry}/docker.io
    testFramework:
      image:
        registry: ${var.image_registry}/docker.io
    image:
      registry: ${var.image_registry}/docker.io
    sidecar:
      image:
        registry: ${var.image_registry}/quay.io
    ingress:
      enabled: true
      ingressClassName: nginx
      hosts:
        - grafana-${local.dns_name}
      path: /
${local.grafana_tls}
sql-exporter:
  image:
    repository: '${var.image_registry}/dockerhub-proxy/burningalchemist/sql_exporter'
tempo:
  tempo:
    repository: ${var.image_registry}/docker.io/grafana/tempo
  EOT
    ) : (<<EOT
  prometheus-node-exporter:
    image:
      registry: ${var.image_registry}/quay.io
  alertmanager:
    alertmanagerSpec:
      image:
        registry: ${var.image_registry}/quay.io
    ingress:
      annotations:
        cert-manager.io/cluster-issuer: zerossl
      labels:
        acme.cert-manager.io/dns01-solver: "true"
  prometheusOperator:
    thanosImage:
      registry:  ${var.image_registry}/quay.io

    prometheusConfigReloader:
      image:
        registry: ${var.image_registry}/quay.io

    prometheusDefaultBaseImageRegistry: ${var.image_registry}/quay.io 
    alertmanagerDefaultBaseImageRegistry: ${var.image_registry}/quay.io 
    image:
      registry: ${var.image_registry}/quay.io

    admissionWebhooks:
      patch:
        image:
          registry: ${var.image_registry}/registry.k8s.io
  kube-state-metrics:
    image:
      registry: ${var.image_registry}/registry.k8s.io
  prometheus:
    annotations:
      reloader.stakater.com/auto: "true"

    thanosServiceMonitor:
      enabled: ${var.thanos_enabled}

    thanosService:
      enabled: ${var.thanos_enabled}
    
    prometheusSpec:
      image:
        registry: ${var.image_registry}/quay.io
      disableCompaction: ${var.thanos_enabled}
      externalLabels:
        clusterAccount: ${var.aws_account}
        clusterRegion: ${var.region}
        clusterName: ${var.label}
        clusterFullName: ${lower("${var.aws_account}-${var.region}-${var.name}")}
${local.thanos_config}
      nodeSelector:
        node_group: static-workers
    ingress:
      annotations:
        cert-manager.io/cluster-issuer: zerossl
      labels:
        acme.cert-manager.io/dns01-solver: "true"
  grafana:
    downloadDashboardsImage:
      registry: ${var.image_registry}/docker.io
    testFramework:
      image:
        registry: ${var.image_registry}/docker.io
    image:
      registry: ${var.image_registry}/docker.io
    sidecar:
      image:
        registry: ${var.image_registry}/quay.io
    ingress:
      annotations:
        cert-manager.io/cluster-issuer: zerossl
      labels:
        acme.cert-manager.io/dns01-solver: "true"
sql-exporter:
  image:
    repository: '${var.image_registry}/dockerhub-proxy/burningalchemist/sql_exporter'
tempo:
  tempo:
    repository: ${var.image_registry}/docker.io/grafana/tempo
EOT
  )
}



resource "aws_route53_record" "grafana-caa" {
  count   = var.monitoring_enabled == true && var.use_static_ssl_certificates == false ? 1 : 0
  zone_id = data.aws_route53_zone.primary[0].zone_id
  name    = lower("grafana.${local.dns_name}")
  type    = "CAA"
  ttl     = 300
  records = [
    "0 issue \"sectigo.com\""
  ]
  provider = aws.dns-control
}


resource "aws_route53_record" "prometheus-caa" {
  count   = var.monitoring_enabled == true && var.use_static_ssl_certificates == false ? 1 : 0
  zone_id = data.aws_route53_zone.primary[0].zone_id
  name    = lower("prometheus.${local.dns_name}")
  type    = "CAA"
  ttl     = 300
  records = [
    "0 issue \"sectigo.com\""
  ]
  provider = aws.dns-control
}

resource "aws_route53_record" "alertmanager-caa" {
  count   = var.monitoring_enabled == true && var.use_static_ssl_certificates == false ? 1 : 0
  zone_id = data.aws_route53_zone.primary[0].zone_id
  name    = lower("alertmanager.${local.dns_name}")
  type    = "CAA"
  ttl     = 300
  records = [
    "0 issue \"sectigo.com\""
  ]
  provider = aws.dns-control
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
    helm_release.external-secrets,
    aws_route53_record.alertmanager-caa,
    aws_route53_record.grafana-caa,
    aws_route53_record.prometheus-caa,
    time_sleep.wait_1_minutes_after_pre_reqs,
    null_resource.update_storage_class
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
  controller:
    service:
      targetPorts:
        https: ${local.backend_port}
${local.lb_config}
    image:
      registry: ${var.image_registry}/registry.k8s.io
      digest: ""
    admissionWebhooks:
      patch:
        image:
          registry: ${var.image_registry}/registry.k8s.io
          digest: ""
  rbac:
    create: true

  admissionWebhooks:
    patch:
      nodeSelector.beta.kubernetes.io/os: linux

  defaultBackend:
    nodeSelector.beta.kubernetes.io/os: linux
  service:
    annotations:
      service.beta.kubernetes.io/oci-load-balancer-internal: "${local.internal_elb}"

authentication:
  ingressUsername: monitoring
  ingressPassword: ${random_password.monitoring-password.result}

${local.alerting_configuration_values}
kube-prometheus-stack:
${local.kube_prometheus_stack_values}
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

