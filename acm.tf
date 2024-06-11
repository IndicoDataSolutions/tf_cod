output "acm_arn" {
  description = "arn of the acm"
  value       = var.enable_waf == true ? aws_acm_certificate_validation.alb[0].certificate_arn : ""
}

resource "aws_acm_certificate" "alb" {
  count             = var.enable_waf == true ? 1 : 0
  domain_name       = local.dns_name
  validation_method = "DNS"
  depends_on = [
    aws_route53_record.ipa-app-caa
  ]
}


resource "aws_route53_record" "alb" {
  for_each = var.enable_waf ? {
    for dvo in aws_acm_certificate.alb[0].domain_validation_options : dvo.domain_name => {
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
  zone_id         = data.aws_route53_zone[0].primary.zone_id
  provider        = aws.dns-control
}


resource "aws_acm_certificate_validation" "alb" {
  count                   = var.enable_waf == true ? 1 : 0
  certificate_arn         = aws_acm_certificate.alb[0].arn
  validation_record_fqdns = [for record in aws_route53_record.alb : record.fqdn]
  depends_on = [
    aws_acm_certificate.alb[0]
  ]
}
