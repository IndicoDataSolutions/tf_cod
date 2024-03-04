
resource "aws_route53_record" "grafana-caa" {
  count = var.monitoring_enabled ? 1 : 0

  zone_id = data.aws_route53_zone.primary.zone_id
  name    = lower("grafana.${local.dns_name}")
  type    = "CAA"
  ttl     = 300
  records = [
    "0 issue \"sectigo.com\""
  ]
  provider = aws.dns-control
}

resource "aws_route53_record" "prometheus-caa" {
  count = var.monitoring_enabled ? 1 : 0

  zone_id = data.aws_route53_zone.primary.zone_id
  name    = lower("prometheus.${local.dns_name}")
  type    = "CAA"
  ttl     = 300
  records = [
    "0 issue \"sectigo.com\""
  ]
  provider = aws.dns-control
}

resource "aws_route53_record" "alertmanager-caa" {
  count = var.monitoring_enabled ? 1 : 0

  zone_id = data.aws_route53_zone.primary.zone_id
  name    = lower("alertmanager.${local.dns_name}")
  type    = "CAA"
  ttl     = 300
  records = [
    "0 issue \"sectigo.com\""
  ]
  provider = aws.dns-control
}
