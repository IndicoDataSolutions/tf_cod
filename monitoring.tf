locals {
  
  # thanos_config = var.thanos_enabled == true ? (<<EOT
  #     thanos: # this is the one being used
  #       blockSize: 5m
  #       objectStorageConfig:
  #         existingSecret:
  #           name: thanos-storage
  #           key: thanos_storage.yaml
  # EOT
  #   ) : (<<EOT
  #     thanos: {}
  # EOT
  # )
  thanos_config = var.thanos_enabled == true ? (<<EOT
      thanos: {}
  EOT
    ) : (<<EOT
      thanos: {}
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
      enabled: false #${var.thanos_enabled}

    thanosService:
      enabled:  false #${var.thanos_enabled}

    prometheusSpec:
      image:
        registry: ${var.image_registry}/quay.io
      disableCompaction: false #${var.thanos_enabled}
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
  enabled: ${var.ipa_enabled}
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
      enabled: false #${var.thanos_enabled}

    thanosService:
      enabled: false #${var.thanos_enabled}
    
    prometheusSpec:
      image:
        registry: ${var.image_registry}/quay.io
      disableCompaction: false #${var.thanos_enabled}
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
  enabled: ${var.ipa_enabled}
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
