output "acm_arn" {
  description = "arn of the acm"
  value       = var.acm_arn == "" ? aws_acm_certificate_validation.acm[0].certificate_arn : var.acm_arn
}

resource "aws_acm_certificate" "acm" {
  count             = var.use_acm && var.acm_arn == "" ? 0 : 1
  domain_name       = local.dns_name
  validation_method = "DNS"
  depends_on = [
    aws_route53_record.ipa-app-caa
  ]
}

resource "aws_route53_record" "acm_validation" {
  for_each = var.use_acm && var.acm_arn == "" ? {
    for dvo in aws_acm_certificate.acm[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.primary[0].zone_id
  provider        = aws.dns-control
}

resource "aws_acm_certificate_validation" "acm" {
  count                   = var.use_acm && var.acm_arn == "" ? 0 : 1
  certificate_arn         = aws_acm_certificate.acm[0].arn
  validation_record_fqdns = [for record in aws_route53_record.acm_validation : record.fqdn]
  depends_on = [
    aws_acm_certificate.acm[0]
  ]
}
