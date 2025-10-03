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
    severity: "${var.alerting_email_severity}"
  slack:
    enabled: ${var.alerting_slack_enabled}
    apiUrl: ${var.alerting_slack_token}
    channel: ${var.alerting_slack_channel}
    severity: "${var.alerting_slack_severity}"
  pagerDuty:
    enabled: ${var.alerting_pagerduty_enabled}
    integrationKey: ${var.alerting_pagerduty_integration_key}
    integrationUrl: "https://events.pagerduty.com/generic/2010-04-15/create_event.json"
    severity: "${var.alerting_pagerduty_severity}"
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
      enabled: false #${var.thanos_enabled}

    thanosService:
      enabled:  false #${var.thanos_enabled}

    prometheusSpec:
      disableCompaction: false #${var.thanos_enabled}
      externalLabels:
        clusterAccount: ${var.account}
        clusterRegion: ${var.region}
        clusterName: ${var.label}
        clusterFullName: ${lower("${var.account}-${var.region}-${var.name}")}
${local.thanos_config}
      nodeSelector:
        node_group: monitoring-workers
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
      enabled: false #${var.thanos_enabled}

    thanosService:
      enabled: false #${var.thanos_enabled}
    
    prometheusSpec:
      disableCompaction: false #${var.thanos_enabled}
      externalLabels:
        clusterAccount: ${var.account}
        clusterRegion: ${var.region}
        clusterName: ${var.label}
        clusterFullName: ${lower("${var.account}-${var.region}-${var.name}")}
${local.thanos_config}
      nodeSelector:
        node_group: monitoring-workers
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
  principal_id         = var.private_dns_zone_id == "System" ? module.cluster.principal_id : azurerm_user_assigned_identity.cluster_dns[0].principal_id
}
