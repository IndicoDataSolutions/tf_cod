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

  fluent_bit_config = var.enable_loki_logging == true ? (<<EOT
fluent-bit:
  enabled: true
  image:
    repository: harbor.devops.indico.io/docker.io/fluent/fluent-bit
  imagePullSecrets:
    - name: harbor-pull-secret
  config:
    inputs: |
      [INPUT]
          name              tail
          path              /var/log/containers/*.log
          exclude_path      /var/log/containers/*_kube-system_*.log,/var/log/containers/*_indico_*.log,/var/log/containers/*_monitoring_*.log,/var/log/containers/*_amazon-guardduty_*.log
          parser            docker
          tag               kube.*
          buffer_chunk_size 64KB
          buffer_max_size 128KB

    filters: |
      [FILTER]
          name                kubernetes
          match               kube.*
          kube_tag_prefix     kube.var.log.containers.
          merge_log           on
          keep_log            off
          k8s-logging.parser  on
          k8s-logging.exclude off
          buffer_size 256KB

    outputs: |
      [OUTPUT]
          name              loki
          match             *
          host              ${var.loki_endpoint}
          port              80
          labels            cluster=${var.label}
          line_format       json
          tenant_id         ${var.label}
          http_user         ${var.loki_username}
          http_passwd       ${var.loki_password}
EOT
    ) : (<<EOT
fluent-bit:
  enabled: false
EOT
  )

  alertmanager_tls = var.acm_arn == "" ? (<<EOT
      tls:
        - secretName: ${var.ssl_static_secret_name}
          hosts:
            - alertmanager-${local.monitoring_domain_name}
  EOT
    ) : (<<EOT
      tls: []
  EOT
  )
  grafana_tls = var.acm_arn == "" ? (<<EOT
      tls:
        - secretName: ${var.ssl_static_secret_name}
          hosts:
            - grafana-${local.monitoring_domain_name}
  EOT
    ) : (<<EOT
      tls: []
  EOT
  )
  prometheus_tls = var.acm_arn == "" ? (<<EOT
      tls:
        - secretName: ${var.ssl_static_secret_name}
          hosts:
            - prometheus-${local.monitoring_domain_name}
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
        - alertmanager-${local.monitoring_domain_name}
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
        - prometheus-${local.monitoring_domain_name}
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
        - grafana-${local.monitoring_domain_name}
      path: /
${local.grafana_tls}
${var.enable_loki_logging == true ? (<<EOT
    additionalDataSources:
      - name: loki
        type: loki
        access: proxy
        basicAuth: true
        url: http://${var.loki_endpoint}
        basicAuthUser: ${var.loki_username}
        secureJsonData:
          basicAuthPassword: ${var.loki_password}
          httpHeaderValue1: ${var.label}
        jsonData:
          httpHeaderName1: "X-Scope-OrgID"
EOT
    ) : (<<EOT
    additionalDataSources: []
EOT
)}
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
${var.enable_loki_logging == true ? (<<EOT
    additionalDataSources:
      - name: loki
        type: loki
        access: proxy
        basicAuth: true
        url: http://${var.loki_endpoint}
        basicAuthUser: ${var.loki_username}
        secureJsonData:
          basicAuthPassword: ${var.loki_password}
          httpHeaderValue1: ${var.label}
        jsonData:
          httpHeaderName1: "X-Scope-OrgID"
EOT
) : (<<EOT
    additionalDataSources: []
EOT
)}
        
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
  name    = lower("grafana.${local.monitoring_domain_name}")
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
  name    = lower("prometheus.${local.monitoring_domain_name}")
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
  name    = lower("alertmanager.${local.monitoring_domain_name}")
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
